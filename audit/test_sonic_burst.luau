-- test_sonic_burst.luau
-- The Sonic Burst ability and the glass it breaks (2026-09-18):
--   1. The charge and the throw: held on the sprint, the stamina bar drains into the charge;
--      the throw is logarithmic in the player's speed (a quick shove for a new player, a
--      massive burst for a veteran) and grows with the charge, capped, never slower than the
--      run; MovementGuard lets a granted dash still count the stages it crosses, and nothing
--      else. The camera punch: 70 -> 88 degrees and an elastic settle.
--   2. The price: a World 3 goal at every rung of the Wins ladder, damped like Flight.
--   3. The server: buy (charged the quoted price, once), equip; a charge and a burst only
--      when owned, equipped, off cooldown and on its feet; every client is told to draw them.
--   4. The client: holding Shift (or the gamepad's sprint, or the Burst button) charges while
--      the stamina drains, a tap is only a sprint, letting go bursts; the frantic, distorted
--      bubble; the Glass Shatter on the screen; the throw that stops at walls; clean-up.
--   5. The Burst button: phones only, the designer's Sprint button, in the right thumb's
--      reach on 8 phones clear of every other control; saved in every place with the card.
--   6. The glass: stage barriers and the finish play the very Glass Shatter the sprint did.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

local function baseEnv()
	local stub = {}
	stub.GetAttribute = function() return nil end
	stub.FindFirstChild = function() return nil end
	stub.WaitForChild = function() return stub end
	return setmetatable({
		game = { GetService = function() return stub end, PlaceId = 0 },
		workspace = stub,
		Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame, Enum = rb.Enum, UDim2 = rb.UDim2,
		print = function() end, warn = function() end,
	}, { __index = _G })
end
local function loadModule(path)
	return luau.load(fs.readFile(path), { environment = baseEnv() })()
end
local Config = loadModule("src/common/ReplicatedStorage/Shared/Config.luau")
local WinsMath = loadModule("src/common/ReplicatedStorage/Shared/WinsMath.luau")
local SonicBurstMath = loadModule("src/common/ReplicatedStorage/Shared/SonicBurstMath.luau")
local HudErgonomics = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")

----------------------------------------------------------------------
-- 1. The throw and the camera punch
----------------------------------------------------------------------
do
	local novice, veteran = SonicBurstMath.DashSpeed(16, Config), SonicBurstMath.DashSpeed(1000, Config)
	assert(novice >= 16 * 5, ("A new player at 16 studs/s dashes 5x faster or more (%.0f)"):format(novice))
	assert(SonicBurstMath.DashDistance(16, Config) >= 25, "...a quick shove of 25+ studs")
	assert(SonicBurstMath.DashDistance(1000, Config) >= 400, ("A veteran at 1000 gets a massive burst (%.0f studs)"):format(SonicBurstMath.DashDistance(1000, Config)))
	local previousSpeed, previousGain = 0, 0
	local previousStepGain = math.huge
	for speed = 16, 1600, 16 do
		local dash = SonicBurstMath.DashSpeed(speed, Config)
		assert(dash >= speed, "Never slower than the run")
		assert(dash >= previousSpeed, "Faster runners dash faster")
		assert(dash <= math.max(speed, Config.AbilitySonicBurstMaxDashSpeed), "Capped")
		local gain = dash - speed
		if dash < Config.AbilitySonicBurstMaxDashSpeed and speed > 16 then
			local stepGain = gain - previousGain
			assert(stepGain <= previousStepGain + 1e-9, "Logarithmic: each extra stud/s adds less burst")
			previousStepGain = stepGain
		end
		previousSpeed, previousGain = dash, gain
	end
	assert(SonicBurstMath.DashSpeed(5000, Config) == 5000, "Beyond the cap the burst never slows anyone down")
	assert(SonicBurstMath.ReferenceSpeed(nil, 40) == 40 and SonicBurstMath.ReferenceSpeed(300, 40) == 300 and SonicBurstMath.ReferenceSpeed(nil, nil) == 16, "It scales from the speedometer, or the current speed if faster")

	-- MovementGuard's segment rule (0.1 s samples): a granted dash stays inside the step it
	-- accepts as a run, so the stages it crosses still count.
	for _, speed in { 16, 60, 100, 300, 600, 1000, 1500 } do
		local multiplier = SonicBurstMath.GuardMultiplier(speed, Config)
		local step = SonicBurstMath.DashSpeed(speed, Config) * 0.1
		local allowed = math.min(256, speed * multiplier * 0.1 * 1.5 + 8)
		assert(multiplier >= 1 and multiplier <= 8 and step <= allowed, ("At %d studs/s a 0.1 s dash step (%.0f) is within the guard's %.0f"):format(speed, step, allowed))
	end
	local guard = fs.readFile("src/common/ServerScriptService/Services/MovementGuard.luau")
	has(guard, 'if (tonumber(player:GetAttribute("SonicBurstUntil")) or 0) > Workspace:GetServerTimeNow() then', "MovementGuard knows a dash is coming")
	has(guard, 'multiplier *= math.clamp(tonumber(player:GetAttribute("SonicBurstGuardMultiplier")) or 1, 1, 8)', "...and allows it, bounded")

	-- 70 -> 88 and an elastic settle.
	local punch = Config.AbilitySonicBurstFovPunch
	assert(70 + punch == 88, "The punch takes 70 degrees to 88")
	assert(math.abs(SonicBurstMath.FovOffset(SonicBurstMath.PunchRise, punch) - punch) < 1e-6, "...at once (0.07 s)")
	local undershoot = 0
	for t = 0.1, 1.2, 0.01 do
		undershoot = math.min(undershoot, SonicBurstMath.FovOffset(t, punch))
	end
	assert(undershoot < 0 and undershoot > -3, ("...then back with a small elastic swing (%.1f)"):format(undershoot))
	assert(math.abs(SonicBurstMath.FovOffset(1.0, punch)) < 0.2 and SonicBurstMath.FovOffset(1.3, punch) == 0, "...settled within about a second")
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau")
	has(client, "currentCamera.FieldOfView = math.clamp(smoothedFov + CameraPunch.FovOffset(), 1, 120)", "The punch rides on top of the game's own FOV easing")

	-- The charge: the stamina this hold has spent (full after 1.6 s of draining, or less on
	-- a small bar), never going back down; an unlimited bar charges with the time sprinted.
	local drain = Config.BoostDrainPerSecond
	assert(SonicBurstMath.ChargeLevel(20, 20, 0, drain, 0) == 0, "Nothing spent, nothing charged")
	local half = SonicBurstMath.ChargeLevel(20, 20 - drain * 0.8, 0.8, drain, 0)
	assert(math.abs(half - 0.5) < 1e-6, ("Half the full-charge drain: half charged (%.2f)"):format(half))
	assert(SonicBurstMath.ChargeLevel(20, 20 - drain * 3, 3, drain, 0) == 1, "Past it: full")
	assert(SonicBurstMath.ChargeLevel(5, 0, 0.9, drain, 0) == 1, "A small bar (Flash, 5) emptied: full")
	assert(SonicBurstMath.ChargeLevel(20, 19, 0.2, drain, 0.7) == 0.7, "It never goes back down during a hold")
	assert(math.abs(SonicBurstMath.ChargeLevel(20, 20, 0.8, drain, 0) - 0.5) < 1e-6, "An unlimited bar charges with the time sprinted")
	assert(SonicBurstMath.ChargeLevel(20, 20, 0.2, drain, 0) == 0, "...but a tap does not")
	local weak, strong = SonicBurstMath.DashDistance(300, Config, SonicBurstMath.MinCharge), SonicBurstMath.DashDistance(300, Config, 1)
	assert(weak < strong and weak > 300 * Config.AbilitySonicBurstDashSeconds, ("A fuller charge throws further (%.0f -> %.0f studs), and even the least is a burst"):format(weak, strong))
	-- The aim: the ground under the pointer, else the way it points; turned toward smoothly.
	local root = rb.Vector3.new(0, 3, 0)
	local eye = rb.Vector3.new(0, 15, 20)
	local toRight = SonicBurstMath.AimAt(root, eye, (rb.Vector3.new(30, 3, 0) - eye).Unit, rb.Vector3.new(0, 0, -1))
	assert((toRight - rb.Vector3.new(1, 0, 0)).Magnitude < 1e-4, "Aimed at the ground to the right: the throw goes right")
	local sky = SonicBurstMath.AimAt(root, eye, rb.Vector3.new(0, 0.5, -1).Unit, rb.Vector3.new(1, 0, 0))
	assert((sky - rb.Vector3.new(0, 0, -1)).Magnitude < 1e-4, "Aimed at the sky: the way it points, flat")
	local feet = SonicBurstMath.AimAt(root, eye, (rb.Vector3.new(0.5, 3, 0.5) - eye).Unit, rb.Vector3.new(0, 0, -1))
	assert(feet.Y == 0 and math.abs(feet.Magnitude - 1) < 1e-6 and feet.Z < -0.9, "Aimed at the player's own feet: the way the pointer ray goes")
	local heading = rb.Vector3.new(0, 0, -1)
	local turned = SonicBurstMath.Steer(heading, rb.Vector3.new(1, 0, 0), 1 / 60)
	assert(turned.X > 0.1 and turned.X < 0.5 and math.abs(turned.Magnitude - 1) < 1e-6, "Steering turns toward the aim, smoothly")
	for _ = 1, 30 do
		heading = SonicBurstMath.Steer(heading, rb.Vector3.new(1, 0, 0), 1 / 60)
	end
	assert(heading.X > 0.99, "...and gets there within half a second")
	local back = SonicBurstMath.Steer(rb.Vector3.new(0, 0, -1), rb.Vector3.new(0, 0, 1), 1)
	assert((back - rb.Vector3.new(0, 0, 1)).Magnitude < 1e-6, "A full turn-around never stalls on a zero direction")

	print(("PASS charge and throw: the stamina drained is the charge; x%.1f dash at 16 studs/s (%.0f studs), %.0f studs at 1000, logarithmic, fuller charge further, capped, never slower; MovementGuard counts its stages; FOV 70 -> 88 and back"):format(
		novice / 16, SonicBurstMath.DashDistance(16, Config), SonicBurstMath.DashDistance(1000, Config)))
end

----------------------------------------------------------------------
-- 2. The price
----------------------------------------------------------------------
do
	local base = Config.AbilitySonicBurstWinsCost
	local world3Lap = Config.World3FinalWinReward
	for _, reward in pairs(Config.World3StageWinRewards) do
		world3Lap += reward
	end
	local previous = math.huge
	local laps = {}
	for _, tier in { 1, 2, 4, 8, 16, 32 } do
		local price = WinsMath.GetProgressionPrice(base, tier, Config.ProgressionPriceMultiplierExponent)
		local lapCount = price / (world3Lap * tier)
		assert(lapCount < previous, ("x%d reaches it faster than the rung below"):format(tier))
		previous = lapCount
		laps[tier] = lapCount
	end
	assert(laps[1] >= 10 and laps[1] <= 15, ("x1: a real World 3 goal, 10-15 laps (%.1f)"):format(laps[1]))
	assert(laps[32] >= 2, ("x32: still over 2 World 3 laps (%.2f)"):format(laps[32]))
	local world1Lap = 1157020
	assert(base / world1Lap > 100, "Out of reach from World 1: it is World 3's")
	local service = fs.readFile("src/common/ServerScriptService/Core/Abilities/SonicBurstService.server.luau")
	has(service, "return WinsMath.GetProgressionPrice(BASE_COST, multiplier, Config.ProgressionPriceMultiplierExponent)", "The service prices it through WinsMath, like Flight")
	has(service, '{ kind = "PurchaseUpgrade", upgradeId = UPGRADE, cost = winsCost(player) },', "...and charges exactly that")
	print(("PASS price: 500M Wins damped like Flight: %.1f World 3 laps at x1, %.1f at x4, %.1f at x16, %.2f at x32"):format(laps[1], laps[4], laps[16], laps[32]))
end

----------------------------------------------------------------------
-- 3. The server
----------------------------------------------------------------------
do
	local source = fs.readFile("src/common/ServerScriptService/Core/Abilities/SonicBurstService.server.luau")
	local chunk = between(source, "local UPGRADE = ", "Action.OnServerEvent:Connect(function(player, action, payload)")
		.. "\nreturn { buy = buy, setEquipped = setEquipped, fire = fire, winsCost = winsCost, startCharge = startCharge, cancelCharge = cancelCharge }"
	local now = 1000
	local sent, broadcast = {}, {}
	local function remoteStub()
		return {
			IsA = function(_, class) return class == "RemoteEvent" end,
			FireClient = function(_, _, message) table.insert(sent, message) end,
			FireAllClients = function(_, message) table.insert(broadcast, message) end,
		}
	end
	local remotes = { SonicBurstAction = remoteStub(), SonicBurstUpdate = remoteStub() }
	local owned = {}
	local profile = { Wins = 0 }
	local ownedFolder = {
		FindFirstChild = function(_, name)
			return if owned[name] then { Value = true, IsA = function(_, class) return class == "BoolValue" end } else nil
		end,
	}
	local attributes = { DataLoaded = true, RealWalkSpeedSelected = 100 }
	local characterAttributes = {}
	local humanoid = { Health = 100, Sit = false, PlatformStand = false }
	local root = {
		IsA = function(_, class) return class == "BasePart" end,
		CFrame = rb.CFrame.new(0, 5, 0),
		AssemblyLinearVelocity = rb.Vector3.new(30, 0, 0),
	}
	local character = {
		FindFirstChildOfClass = function() return humanoid end,
		FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
		GetAttribute = function(_, name) return characterAttributes[name] end,
	}
	local players = {}
	local player = {
		Parent = players,
		UserId = 1,
		Character = character,
		GetAttribute = function(_, name) return attributes[name] end,
		SetAttribute = function(_, name, value) attributes[name] = value end,
		FindFirstChild = function(_, name)
			return if name == "SpeedsterData" then { FindFirstChild = function(_, n) return if n == "OwnedUpgrades" then ownedFolder else nil end } else nil
		end,
	}
	local commits = {}
	local DataService = {
		GetHandle = function() return {} end,
		NewOperationId = function() return "op" end,
		Commit = function(_, request)
			table.insert(commits, request)
			for _, command in request.commands do
				if command.kind == "PurchaseUpgrade" then
					if profile.Wins < command.cost then
						return { kind = "Rejected", error = { code = "InsufficientFunds" } }
					end
				end
			end
			for _, command in request.commands do
				if command.kind == "PurchaseUpgrade" then
					profile.Wins -= command.cost
					owned[command.upgradeId] = true
				elseif command.kind == "GrantUpgrade" then
					owned[command.upgradeId] = true
				elseif command.kind == "RemoveUpgrade" then
					owned[command.upgradeId] = nil
				end
			end
			return { kind = "Committed" }
		end,
	}
	local api = luau.load(chunk, {
		environment = setmetatable({
			Config = Config,
			WinsMath = WinsMath,
			SonicBurstMath = SonicBurstMath,
			DataService = DataService,
			Players = players,
			ReplicatedStorage = { WaitForChild = function() return { FindFirstChild = function(_, name) return remotes[name] end } end },
			Workspace = { GetServerTimeNow = function() return now end },
			Instance = rb.Instance,
			Vector3 = rb.Vector3,
			typeof = typeof,
			os = { clock = function() return now end },
			_G = { SpeedsterGetPermanentWinsMultiplier = function() return 16 end },
			warn = function() end,
		}, { __index = _G }),
	})()
	local price = api.winsCost(player)
	assert(price == WinsMath.GetProgressionPrice(Config.AbilitySonicBurstWinsCost, 16, Config.ProgressionPriceMultiplierExponent), "Priced against the canonical permanent multiplier (x16 here)")

	api.startCharge(player)
	assert(#broadcast == 0 and sent[#sent].Kind == "Denied" and sent[#sent].Reason == "NotEquipped", "Not owned: it does not charge")
	profile.Wins = price - 1
	api.buy(player)
	assert(not owned.SonicBurst and profile.Wins == price - 1 and sent[#sent].Message == "Not Enough Wins", "One Win short: nothing is charged")
	profile.Wins = price + 5
	api.buy(player)
	assert(owned.SonicBurst and owned.__AbilityEquipped_SonicBurst and profile.Wins == 5, "Bought: charged the quoted price, owned and equipped in one transaction")
	assert(attributes.SonicBurstOwned == true and attributes.SonicBurstEquipped == true, "...and the client is told")
	local before = #commits
	api.buy(player)
	assert(#commits == before and profile.Wins == 5, "Buying again charges nothing")

	api.fire(player, rb.Vector3.new(1, 0, 0), 1)
	assert(#broadcast == 1 and broadcast[1].Kind == "ChargeEnd" and sent[#sent].Reason == "NotCharging", "No burst without a charge the server saw begin")
	api.startCharge(player)
	assert(broadcast[#broadcast].Kind == "Charge" and broadcast[#broadcast].Player == player, "Charging: every client draws the bubble")
	now += 1
	api.fire(player, rb.Vector3.new(0, 3, -4), 0.8)
	local burst = broadcast[#broadcast]
	assert(burst.Kind == "Burst" and burst.Player == player and burst.Charge == 0.8, "Let go: every client sees it burst, at its charge")
	assert(math.abs(burst.Direction.Magnitude - 1) < 1e-6 and burst.Direction.Y == 0 and burst.Direction.Z < 0, "...flat, the way the player asked")
	assert(attributes.SonicBurstUntil > now and attributes.SonicBurstGuardMultiplier >= 1, "...and MovementGuard is told a dash is coming")
	local count = #broadcast
	api.startCharge(player)
	assert(#broadcast == count and sent[#sent].Reason == "Cooldown" and sent[#sent].ReadyIn > 8, "Again at once: on cooldown")
	now += Config.AbilitySonicBurstCooldownSeconds
	characterAttributes.Ragdolled = true
	api.startCharge(player)
	assert(#broadcast == count and sent[#sent].Reason == "NotReady", "Ragdolled: no")
	characterAttributes.Ragdolled = nil
	attributes.FlightAbilityActive = true
	api.startCharge(player)
	assert(#broadcast == count and sent[#sent].Reason == "NotReady", "Flying: no")
	attributes.FlightAbilityActive = nil
	humanoid.Health = 0
	api.startCharge(player)
	assert(#broadcast == count, "Dead: no")
	humanoid.Health = 100
	api.startCharge(player)
	api.cancelCharge(player)
	assert(broadcast[#broadcast].Kind == "ChargeEnd", "Called off: every client drops the bubble")
	api.startCharge(player)
	api.fire(player, nil, 7)
	assert(broadcast[#broadcast].Kind == "Burst" and broadcast[#broadcast].Direction.Z < -0.99 and broadcast[#broadcast].Charge == 1,
		"No direction sent: the way the root looks; the charge is kept within 0..1")
	api.setEquipped(player, false)
	now += 100
	api.startCharge(player)
	assert(sent[#sent].Reason == "NotEquipped", "Unequipped: no charge")
	print("PASS server: bought once at the quoted price, equipped; charges and bursts only when owned, equipped, off cooldown and on its feet, broadcast to every client")
end

----------------------------------------------------------------------
-- 4. The client
----------------------------------------------------------------------
do
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SonicBurstClient.client.luau")
	-- The charge flow, run: startCharge, the per-frame step and releaseCharge.
	local chunk = between(client, "local cooldownEndsAt = 0", "Update.OnClientEvent:Connect(function(message)")
		.. "\nreturn { start = startCharge, release = releaseCharge, cancel = cancelCharge, charging = function() return charging end, cooldownEndsAt = function() return cooldownEndsAt end }"
	-- (startBubble and GlassShatter stand in for the real ones below.)
	local now = 100
	local running = true
	local attributes = { SonicBurstEquipped = true, CurrentStamina = 20, IsBoosting = true }
	local humanoid = { Health = 100, Sit = false }
	local character = {
		FindFirstChildOfClass = function() return humanoid end,
		FindFirstChild = function() return {} end,
		GetAttribute = function() return nil end,
	}
	local sent, bubbles, screens, bursts = {}, 0, 0, {}
	local step
	local flow = luau.load(chunk, {
		environment = setmetatable({
			player = {
				Character = character,
				GetAttribute = function(_, name) return attributes[name] end,
			},
			UserInputService = { GetFocusedTextBox = function() return nil end },
			SonicBurstMath = SonicBurstMath,
			Action = { FireServer = function(_, ...) table.insert(sent, { ... }) end },
			RunService = { Heartbeat = { Connect = function(_, fn) step = fn end } },
			startBubble = function()
				bubbles += 1
				return { SetLevel = function() end, Cancel = function() bubbles -= 1 end }
			end,
			GlassShatter = { Charge = function()
				screens += 1
				return { SetLevel = function() end, Stop = function() screens -= 1 end }
			end },
			burst = function(_, effect, level, isLocal)
				table.insert(bursts, { Level = level, Local = isLocal })
			end,
			aimDirection = function() return rb.Vector3.new(0, 0, -1) end,
			isRunning = function() return running end,
			COOLDOWN = Config.AbilitySonicBurstCooldownSeconds,
			SHOW_AFTER = SonicBurstMath.ShowAfterSeconds,
			DRAIN = Config.BoostDrainPerSecond,
			os = { clock = function() return now end },
		}, { __index = _G }),
	})()
	local function hold(seconds)
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt + 0.5) do
			now += dt
			-- The server drains the bar only while the sprint runs (Bootstrap).
			if attributes.IsBoosting and running then
				attributes.CurrentStamina = math.max(0, attributes.CurrentStamina - Config.BoostDrainPerSecond * dt)
			end
			step(dt)
		end
	end
	-- A tap of Shift is only a sprint.
	flow.start()
	hold(0.1)
	flow.release()
	assert(#sent == 0 and bubbles == 0 and #bursts == 0, "A tap of the sprint is only a sprint: no bubble, no burst")
	-- Shift held standing still (2026-09-18: it used to charge nothing): it charges with
	-- time, costs no stamina, and letting go bursts.
	running = false
	attributes.CurrentStamina = 20
	flow.start()
	hold(0.8)
	local standing = flow.charging().Level
	assert(sent[1][1] == "Charge" and bubbles == 1, "Held standing still: the bubble comes up")
	assert(standing > 0.25 and attributes.CurrentStamina == 20, ("...it charges with time (%.2f) and costs no stamina"):format(standing))
	flow.release()
	assert(sent[2][1] == "Fire" and #bursts == 1 and bursts[1].Local, "...and letting go bursts from a standstill")
	now += 20
	table.clear(sent)
	table.clear(bursts)
	bubbles = 0
	running = true
	-- Held: the bubble after 0.2 s, the charge from the stamina drained.
	attributes.CurrentStamina = 20
	flow.start()
	hold(0.3)
	assert(sent[1][1] == "Charge" and bubbles == 1 and screens == 1, "Held: the bubble and the trembling glass, and every client is told")
	hold(0.5)
	local level = flow.charging().Level
	assert(level > 0.4 and level < 0.6, ("0.8 s of draining: about half charged (%.2f)"):format(level))
	flow.release()
	assert(sent[2][1] == "Fire" and math.abs(sent[2][2].Charge - level) < 1e-6 and bursts[1].Local and bubbles == 1 and screens == 0,
		"Let go: it bursts at that charge (the bubble goes into the burst)")
	assert(flow.cooldownEndsAt() > now + 8, "...and recharges")
	flow.start()
	assert(flow.charging() == nil, "Not while it recharges (the sprint still works)")
	-- Too little: the end of a sprint, not a burst.
	now += 20
	bubbles = 0
	attributes.CurrentStamina = 20
	flow.start()
	hold(0.33)
	assert(bubbles == 1, "(the bubble is up)")
	flow.release()
	assert(sent[#sent][1] == "Cancel" and #bursts == 1 and bubbles == 0, "Let go with too little charge: called off, no burst")
	-- Dying mid-charge calls it off.
	flow.start()
	hold(0.3)
	humanoid.Health = 0
	hold(0.05)
	assert(flow.charging() == nil and sent[#sent][1] == "Cancel" and bubbles == 0, "Dying mid-charge calls it off")
	humanoid.Health = 100

	-- Holding the sprint drives it: Shift and the gamepad's trigger (SpeedsterClient's
	-- SprintHeld), and on phones the Burst button, which sprints while held.
	has(client, 'player:GetAttributeChangedSignal("SprintHeld"):Connect(function()', "Holding the sprint charges it, letting go bursts")
	local speedster = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau")
	has(speedster, 'player:SetAttribute("SprintHeld", value)', "SpeedsterClient says when the sprint is held")
	has(speedster, 'boostControl.Name = "SpeedsterBoostControl"', "...and lets the Burst button sprint")
	has(client, "boostControl:Fire(true)\n\t\tend\n\t\tstartCharge()", "The Burst button sprints (draining the bar) and charges while held")
	has(client, "if boostControl and not sprintBefore then\n\t\t\tboostControl:Fire(false)", "...and puts the sprint back as it was")
	has(client, 'return if flight then "Shift: Charge the run | Space: Fly" else "Hold Shift to charge the run"', "The stamina bar says how")
	local hud = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(hud, 'local burstHint = player:GetAttribute("SonicBurstHint")', "...in the bar's own hint label, like Fly's")

	-- The bubble: distorted and frantic.
	has(client, "glass.Material = Enum.Material.Glass", "Glass outside...")
	has(client, "energy.Material = Enum.Material.ForceField", "...shimmering energy inside")
	has(client, "TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)", "Pulsing: two beats every 0.4 s, for as long as it charges")
	has(client, "* (1 + 0.12 * pulse.Value + rng(-0.04, 0.04) * wild)", "...shaking, harder as it fills")
	has(client, "local SHARDS = 10", "Glass shards whirling round it")
	has(client, "local on = math.random() < 0.55 + 0.4 * level", "Flickering lightning, more of it as it fills")
	has(client, "state.Screen = GlassShatter.Charge({ Always = true })", "The player's own screen: the glass trembling, the view warping")
	has(client, "task.defer(GlassShatter.Play, shatter)", "The burst: the very Glass Shatter on the screen")
	has(client, "CameraPunch.Fov(FOV_PUNCH)", "...with the FOV punch")
	has(client, "local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)\n\t\treturn SonicBurstMath.AimAt(root.Position, ray.Origin, ray.Direction, camera.CFrame.LookVector)",
		"The throw goes where the mouse pointer is...")
	has(client, "and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter", "...unless shift-lock holds the mouse")
	has(client, "return SonicBurstMath.FlatDirection(camera.CFrame.LookVector, fallback)", "...else where the camera looks (gamepads, phones, shift-lock)")
	has(client, "direction = SonicBurstMath.Steer(direction, aimDirection(character), dt)", "It keeps turning with the aim while it lasts")
	assert(not string.find(client, "if player:GetAttribute(\"IsBoosting\") == true and isRunning(character) then", 1, true), "Holding the sprint charges it, running or not")
	has(client, "local ahead = Workspace:Spherecast(root.Position, WALL_PROBE_RADIUS, direction * (dashSpeed * dt + 1.5), params)", "The throw looks ahead every frame...")
	has(client, "root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)\n\t\t\tendDash()", "...and stops short of a wall")
	has(client, "params.RespectCanCollide = true", "...only real walls")
	has(client, "character:SetAttribute(DASH_ATTRIBUTE, true)", "The run controller stands aside during the throw")
	local movement = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
	has(movement, 'if character:GetAttribute("SonicBurstDashLocal") == true then\n\t\treturn true', "...InstantMovementController")
	-- Clean-up.
	has(client, "for _, connection in effect.Connections do\n\t\t\tconnection:Disconnect()\n\t\tend\n\t\tpulseTween:Cancel()\n\t\tholder:Destroy()", "A bubble takes its loop, tween and parts with it")
	has(client, "if t > REMOTE_CHARGE_TIMEOUT then\n\t\t\t\teffect.Cancel()", "Another player's bubble that never hears its end goes by itself")
	has(client, "other.CharacterRemoving:Connect(dropCharacter)", "A character that respawns drops its burst")
	has(client, "humanoid.Died:Connect(function()\n\t\t\t\tdropCharacter(character)", "...and one that dies")
	has(client, "Players.PlayerRemoving:Connect(function(other)\n\tdropCharacter(other.Character)", "...and one whose player leaves")
	has(client, "state.Connection:Disconnect()", "The throw's loop ends")
	local glass = fs.readFile("src/common/ReplicatedStorage/Shared/GlassShatter.luau")
	has(glass, "function GlassShatter.Charge(opts)", "GlassShatter has the charge")
	has(glass, "RunService:UnbindFromRenderStep(name)\n  folder:Destroy();correction:Destroy();blur:Destroy()", "...which takes its glass and effects away")
	local camera = fs.readFile("src/common/ReplicatedStorage/Shared/CameraPunch.luau")
	has(camera, "shaken.Camera.CFrame = shaken.Before", "The shake restores the exact camera CFrame")
	print("PASS client: a tap is a sprint; held standing still it charges with time; running, the stamina drains into the charge under a frantic, distorted bubble; let go, the Glass Shatter and a throw steered by the pointer or camera that stops at walls; all cleaned up")
end

----------------------------------------------------------------------
-- 5. The Burst button (phones), and the saved UI
----------------------------------------------------------------------
do
	local PHONES = { { 844, 390 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 896, 414 }, { 932, 430 }, { 915, 412 }, { 800, 360 } }
	for _, s in PHONES do
		for _, topBar in { 0, 36, 58 } do
			local width, hudHeight = s[1], s[2] - topBar
			local column = HudErgonomics.PhoneColumn(s[1], s[2], true, false, 2, topBar)
			local g = column.Speedometer.Rect
			local gauge = { Left = g.Left, Right = g.Right, Top = g.Top - topBar, Bottom = g.Bottom - topBar }
			local cardsWidth, cardsHeight = (3 * 44 + 2 * 5) * 0.7, 48 * 0.7
			local buffs = { Left = column.Buffs.Right - cardsWidth, Right = column.Buffs.Right, Top = column.Buffs.Y - cardsHeight / 2, Bottom = column.Buffs.Y + cardsHeight / 2 }
			local button = HudErgonomics.AbilityButton(width, hudHeight, { buffs, gauge })
			local where = ("%dx%d (top bar %d)"):format(s[1], s[2], topBar)
			assert(button.Size >= 38 and button.Size <= 46, where .. ": a 38-46 px button")
			assert(button.Left >= width / 2 and button.Right <= width and button.Top >= 0 and button.Bottom <= hudHeight, where .. ": on screen, on the right thumb's side")
			for name, other in {
				jump = HudErgonomics.JumpButton(width, hudHeight),
				sprint = HudErgonomics.SprintButton(width, hudHeight),
				thumbstick = HudErgonomics.Thumbstick(width, hudHeight),
				boosts = buffs,
				speedometer = gauge,
			} do
				assert(not HudErgonomics.Overlaps(button, other, 6), where .. ": clear of the " .. name)
			end
		end
	end
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local starter = place:GetService("StarterGui")
		local button = starter.Mainhud:FindFirstChild("SonicBurstButton")
		local sprint = starter.Mainhud.MobileSprint
		assert(button and button:IsA("TextButton") and button.Visible == false and button.Text == "Burst", world .. ": the Burst button is saved in the Main HUD, hidden until equipped")
		assert(button.BackgroundColor3 == sprint.BackgroundColor3 and button.TextColor3 == sprint.TextColor3 and button.FontFace == sprint.FontFace,
			world .. ": ...in the designer's Sprint button's design")
		local strokes = 0
		for _, child in button:GetChildren() do
			if child:IsA("UIStroke") then
				strokes += 1
			end
		end
		local corner = button:FindFirstChildOfClass("UICorner")
		assert(strokes == 2 and corner.TopLeftRadius == rb.UDim.new(0.5, 0) and corner.BottomRightRadius == rb.UDim.new(0.5, 0) and button:FindFirstChild("PressScale") and button:FindFirstChild("Label"),
			world .. ": ...its two outlines, round like the Sprint button on phones, a pressed state, and child label")
		local list = starter.Abilities.Panel.ScrollingFrame
		local card = list:FindFirstChild("SonicBurstCard")
		assert(card and card.LayoutOrder == 2, world .. ": the Sonic Burst card is saved in the Abilities panel, after Flight")
		local titles = {}
		for _, child in card:GetChildren() do
			if child:IsA("TextLabel") then
				titles[child.Text] = true
			end
		end
		assert(titles["Sonic Burst"] and titles["9s cooldown"], world .. ": ...titled, with its cooldown")
		assert(card.Frame.RobuxPurchase.Visible == true and card.Frame.WinsPurchase.Visible == true, world .. ": ...bought with Wins or Robux")
		local flight = list:FindFirstChild("Frame")
		local flightTitles = {}
		for _, child in flight:GetChildren() do
			if child:IsA("TextLabel") then
				flightTitles[child.Text] = true
			end
		end
		assert(flightTitles.Fly and flight.Frame.RobuxPurchase.Visible == true, world .. ": the designer's Flight card is untouched")
		for _, path in {
			{ "ServerScriptService", "Core", "Abilities", "SonicBurstService" },
			{ "StarterPlayer", "StarterPlayerScripts", "Movement", "SonicBurstClient" },
			{ "StarterPlayer", "StarterPlayerScripts", "Movement", "StageBarrierShatter" },
			{ "StarterPlayer", "StarterPlayerScripts", "Movement", "SurfboardPose" },
			{ "ReplicatedStorage", "Shared", "SonicBurstMath" },
			{ "ReplicatedStorage", "Shared", "GlassBurst" },
			{ "ReplicatedStorage", "Shared", "CameraPunch" },
			{ "ReplicatedStorage", "Shared", "SonicBurstUi" },
			{ "ReplicatedStorage", "Shared", "SkinPreview" },
			{ "ReplicatedStorage", "Shared", "SurfboardStance" },
		} do
			local node = place
			for _, name in path do
				node = node and node:FindFirstChild(name)
			end
			assert(node and node:IsA("LuaSourceContainer"), world .. ": " .. table.concat(path, "."))
		end
	end
	local panel = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AbilitiesPanel.client.luau")
	has(panel, 'burstAction:FireServer("BuyWins")', "The card buys it")
	has(panel, 'burstAction:FireServer(burstState.Equipped and "Unequip" or "Equip")', "...and equips it")
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SonicBurstClient.client.luau")
	has(client, "button.Visible = equipped() and touchOnly()", "The button shows on phones and tablets only")
	has(client, "local layoutButton\n", "layoutButton is declared before the HUD handler calls it")
	print("PASS Burst button: phones only, the designer's Sprint button, clear of jump, Sprint, thumbstick, boosts and speedometer on 8 phones; button and card saved in every place")
end

----------------------------------------------------------------------
-- 6. The glass
----------------------------------------------------------------------
do
	local GlassBurst = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/GlassBurst.luau"), {
		environment = setmetatable({
			game = { GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return { WaitForChild = function() return { WaitForChild = function() return "Config" end } end }
				end
				return {}
			end },
			require = function() return Config end,
			Color3 = rb.Color3,
			CFrame = rb.CFrame,
			Vector2 = rb.Vector2,
		}, { __index = _G }),
	})()
	for _ = 1, 20 do
		local pieces = GlassBurst.Slice(0, 0, 14, 11, 4)
		local area = 0
		for _, piece in pieces do
			area += piece.W * piece.H
		end
		assert(#pieces == 16 and #pieces <= GlassBurst.MaxShards and math.abs(area - 14 * 11) < 1e-6, "A barrier breaks into 16 shards that are the whole pane")
	end
	assert(GlassBurst.SoundId == "rbxassetid://9114615010", "The smash: ProSoundEffects' Glass Smashes 7")

	-- A new stage crossed at speed breaks its barrier; a respawn, a teleport or a walk do not.
	local source = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/StageBarrierShatter.client.luau")
	-- breakBarrier stands in for the real one: it counts, and stamps the time as it does.
	local chunk = "local lastBreakAt = -math.huge\nlocal function breakBarrier() countBreak(); lastBreakAt = os.clock() end\n"
		.. between(source, "local reachedStage = ", "-- The finish:")
	local attributes, handler = { LastReachedStage = 1 }, nil
	local speed, now, breaks = 60, 100, 0
	local env = setmetatable({
		player = {
			GetAttribute = function(_, name) return attributes[name] end,
			GetAttributeChangedSignal = function() return { Connect = function(_, fn) handler = fn end } end,
		},
		rootOf = function() return {} end,
		flatVelocity = function() return rb.Vector3.new(speed, 0, 0) end,
		countBreak = function() breaks += 1 end,
		MIN_SPEED = 45,
		COOLDOWN = 1.5,
		os = { clock = function() return now end },
	}, { __index = _G })
	luau.load(chunk, { environment = env })()
	local function reach(stage)
		attributes.LastReachedStage = stage
		handler()
	end
	reach(2)
	assert(breaks == 1, "Stage 2 crossed at 60 studs/s: the barrier breaks")
	now += 0.5
	speed = 60
	reach(3)
	assert(breaks == 1, "Not twice within a moment")
	now += 5
	speed = 20
	reach(4)
	assert(breaks == 1, "Walking in (20 studs/s): no")
	speed = 90
	reach(1)
	reach(1)
	assert(breaks == 1, "A respawn back to Stage 1: no")
	now += 5
	reach(2)
	assert(breaks == 2, "Crossing again at speed: again")
	has(source, "local MIN_SPEED = math.max(10, tonumber(Config.StageBarrierShatterMinSpeed) or 45)", "The speed a barrier needs comes from Config")
	has(source, "task.defer(GlassShatter.Play, shatter)", "A barrier plays the full-screen Glass Shatter")
	local settings = between(source, "local SHATTER = {", "}")
	for _, line in { "Distance = 3.2,", "HoldTime = 0.02,", "Depth = 4,", "Intensity = 2.2,", "Thickness = 0.07,", "Transparency = 0.4,",
		"Color = Color3.fromRGB(250, 252, 255),", "CameraPunch = true,", "Shockwave = true," } do
		has(settings, line, "...with exactly the sprint's old settings: " .. line)
	end
	local shatter = fs.readFile("src/common/ReplicatedStorage/Shared/GlassShatter.luau")
	has(shatter, "GlassShatter.SoundId=ok and type(Config)==\"table\" and Config.GlassBreakSoundId or nil", "...now with the smash sound")
	has(source, '{ Folder = "World3ManualStagePads_Runtime", Attribute = "World3FinalWinStagePad" }', "The finish is each world's final Win pad")
	has(source, "if flat.Magnitude <= FINISH_REACH and math.abs(offset.Y) <= 15 and flat:Dot(velocity) > 0 then", "...run at, at speed, it breaks before the pad sends the player home")
	print("PASS glass: stage barriers and the finish play the very Glass Shatter (with its smash) at speed; walking, respawns and the sprint never do")
end

print("ALL SONIC BURST CHECKS PASSED")
