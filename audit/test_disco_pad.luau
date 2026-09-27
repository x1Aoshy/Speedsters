-- test_disco_pad.luau
-- The admin disco's perk (2026-09-18 pre-launch review): while the party is on, every
-- player gets the passive Disco multiplier on their Speed gain, wherever they are; a
-- player dancing (the dance floor's dance or /e dance), standing still on the ground, gets
-- x100 and earns Speed as if running while they dance. The HUD shows a [Disco] card; the
-- party ending takes it all away.
local fs = require("@lune/fs")
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

local SERVICE = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
local CONFIG = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local multiplier = tonumber(string.match(CONFIG, "PassiveSpeedMultiplier = ([%d%.]+),"))
local danceMultiplier = tonumber(string.match(CONFIG, "DanceSpeedMultiplier = ([%d%.]+),"))
assert(multiplier and multiplier > 1, "Everyone gets a Disco multiplier")
assert(danceMultiplier == 100, "Dancing gets x100")

----------------------------------------------------------------------
-- 1. The server: everyone gets the passive buff, dancers get x100
----------------------------------------------------------------------
do
	local V3 = rb.Vector3
	local floor = V3.new(290, 100, -1755)
	local attributes = { AdminDiscoUntil = 5000, AdminDiscoFloor = floor, AdminDiscoFloorSize = V3.new(112, 0, 140) }
	local function player(position, options)
		options = options or {}
		local character = rb.Instance.new("Model")
		local root = rb.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = rb.CFrame.new(position)
		root.Parent = character
		-- Lune's Humanoid has no FloorMaterial or MoveDirection: a stand-in with what the
		-- server reads.
		local humanoid = {
			Health = if options.dead then 0 else 100,
			FloorMaterial = if options.air then rb.Enum.Material.Air else rb.Enum.Material.Plastic,
			Sit = options.sit == true,
			MoveDirection = options.move or V3.zero,
		}
		local own = {}
		local model = {
			GetAttribute = function(_, name)
				return if name == "Ragdolled" then options.ragdolled else nil
			end,
			FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then root else nil
			end,
			FindFirstChildOfClass = function(_, class)
				return if class == "Humanoid" then humanoid else nil
			end,
		}
		root:SetAttribute("Velocity", options.velocity or V3.zero)
		return {
			Character = model,
			Humanoid = humanoid,
			Root = root,
			GetAttribute = function(_, name)
				return own[name]
			end,
			SetAttribute = function(_, name, value)
				own[name] = value
			end,
		}
	end
	local walker = player(floor + V3.new(20, 3, -30), { move = V3.new(1, 0, 0), velocity = V3.new(16, 0, 0) })
	local faraway = player(floor + V3.new(900, 3, 0))
	local dancer = player(floor + V3.new(0, 3, 0))
	local emoter = player(floor + V3.new(600, 3, 400)) -- /e dance, far from the dance floor
	local cheater = player(floor + V3.new(10, 3, 0), { move = V3.new(0, 0, 1), velocity = V3.new(0, 0, 20) })
	local airborne = player(floor + V3.new(-10, 9, 0), { air = true })
	local treadmill = player(floor + V3.new(30, 3, 0))
	local dead = player(floor + V3.new(0, 3, 5), { dead = true })
	local ragdoll = player(floor + V3.new(0, 3, 9), { ragdolled = true })
	treadmill:SetAttribute("IsOnTreadmill", true)
	local players = { walker, faraway, dancer, emoter, cheater, airborne, treadmill, dead, ragdoll }
	local clock = 1000
	local remotes = {}
	local allowed = true
	local env = setmetatable({
		Config = { AdminDisco = { PassiveSpeedMultiplier = multiplier, DanceSpeedMultiplier = danceMultiplier } },
		Workspace = { GetAttribute = function(_, name) return attributes[name] end },
		Players = {
			GetPlayers = function() return players end,
			PlayerRemoving = { Connect = function(_, fn) remotes.Leaving = fn end },
		},
		RateLimiter = { Allow = function() return allowed end },
		remote = function(name)
			local event = { OnServerEvent = { Connect = function(_, fn) remotes[name] = fn end } }
			return event
		end,
		Enum = rb.Enum,
		Vector3 = V3,
		os = { time = function() return clock end },
	}, { __index = _G })
	-- Lune's parts have no .AssemblyLinearVelocity: the stand-in's velocity through an attribute.
	local chunk = string.gsub(between(SERVICE, 'local DISCO_PAD_ATTRIBUTE = "DiscoSpeedGainMultiplier"', "local function stopDisco()"), "root%.AssemblyLinearVelocity", 'root:GetAttribute("Velocity")')
	local updateDiscoPad = luau.load(chunk .. "\nreturn updateDiscoPad", { environment = env })()
	local report = assert(remotes.AdminDiscoDance, "Clients report their dancing through AdminDiscoDance")

	updateDiscoPad()
	for _, who in { walker, faraway, dancer, emoter, cheater, airborne, treadmill } do
		assert(who:GetAttribute("DiscoSpeedGainMultiplier") == multiplier, "Everyone alive gets x" .. multiplier .. ", on the dance floor or not")
		assert(who:GetAttribute("DiscoDancing") == nil, "...nobody dances until they do")
	end
	assert(dead:GetAttribute("DiscoSpeedGainMultiplier") == nil and ragdoll:GetAttribute("DiscoSpeedGainMultiplier") == nil, "Dead or ragdolled: none")

	for _, who in { dancer, emoter, cheater, airborne, treadmill } do
		report(who, true)
	end
	report(walker, "yes") -- only a real true counts
	updateDiscoPad()
	assert(dancer:GetAttribute("DiscoSpeedGainMultiplier") == danceMultiplier and dancer:GetAttribute("DiscoDancing") == true, "Dancing on the dance floor: x100, and paid while dancing")
	assert(emoter:GetAttribute("DiscoSpeedGainMultiplier") == danceMultiplier and emoter:GetAttribute("DiscoDancing") == true, "/e dance anywhere: x100 too")
	assert(cheater:GetAttribute("DiscoSpeedGainMultiplier") == multiplier and cheater:GetAttribute("DiscoDancing") == nil, "Saying you dance while running earns nothing more")
	assert(airborne:GetAttribute("DiscoSpeedGainMultiplier") == multiplier, "...nor in the air")
	assert(treadmill:GetAttribute("DiscoSpeedGainMultiplier") == multiplier, "...nor on a treadmill")
	assert(walker:GetAttribute("DiscoSpeedGainMultiplier") == multiplier, "Anything but true is not a dance")

	report(dancer, false)
	updateDiscoPad()
	assert(dancer:GetAttribute("DiscoSpeedGainMultiplier") == multiplier and dancer:GetAttribute("DiscoDancing") == nil, "Stopping the dance: back to the passive buff")
	allowed = false
	report(dancer, true)
	updateDiscoPad()
	assert(dancer:GetAttribute("DiscoDancing") == nil, "A flood of reports is dropped")
	allowed = true
	remotes.Leaving(emoter)
	updateDiscoPad()
	assert(emoter:GetAttribute("DiscoDancing") == nil, "Leaving forgets the dance")

	clock = 6000
	updateDiscoPad()
	for _, who in players do
		assert(who:GetAttribute("DiscoSpeedGainMultiplier") == nil and who:GetAttribute("DiscoDancing") == nil, "The party ending takes it all away")
	end

	has(SERVICE, "-- The party is over: nobody keeps the Disco bonus.\n\tpcall(updateDiscoPad)", "Stopping the disco clears it at once")
	has(SERVICE, "task.wait(DISCO_PAD_INTERVAL)\n\t\tpcall(updateDiscoPad)", "It is checked a few times a second, safely")
	has(SERVICE, "if player:GetAttribute(DISCO_PAD_ATTRIBUTE) ~= want then", "...and written only when it changes")

	-- Dancing pays as if running: the running loop counts a dancer as moving (not boosted),
	-- and the Speed gain carries the x100.
	local bootstrap = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
	has(bootstrap, 'local dancing = player:GetAttribute("DiscoDancing") == true', "The running loop sees who dances")
	has(bootstrap, "speedPerTick > 0 and (dancing or isMoving(player)) then", "...and pays them while they stand still dancing")
	has(bootstrap, 'if not dancing and player:GetAttribute("IsBoosting") == true then', "...at the walking rate (no sprint on top)")

	-- The client: says when a dance plays on its character (the floor's or /e dance).
	local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	has(effects, 'ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminDiscoDance", 60)', "The client finds the report remote without holding up the effects")
	has(effects, "for _, track in animator:GetPlayingAnimationTracks() do", "It looks at what plays on the character")
	has(effects, 'if (id and DANCE_IDS[id]) or string.find(name, "dance", 1, true) then', "...the dance floor's dances and /e dance, dance2, dance3")
	has(effects, "if dancingNow ~= sent or (on and os.clock() - sentAt >= 2) then", "Reported on change, and again now and then")
	has(effects, '"Dance for x100 Speed! Stand still here or type /e dance"', "The sign over the ball says how")
	-- The R15 and R6 dances the dance floor plays are Roblox's /e dance ones.
	for _, id in { "507771019", "507776043", "507777268", "182435998", "182436842", "182436935" } do
		has(effects, '"rbxassetid://' .. id .. '"', "The dance list has " .. id)
	end
	print("PASS perk: during the disco everyone gets x" .. multiplier .. "; standing still dancing (floor or /e dance) x100 and paid as if running; false claims, running, air, treadmills earn no more")
end

----------------------------------------------------------------------
-- 2. The Speed gain: doubled on the pad, and never lowered by it
----------------------------------------------------------------------
do
	local source = fs.readFile("src/common/ServerScriptService/Services/Stats/StatsService.luau")
	local StatsService = luau.load(source, { environment = setmetatable({}, { __index = _G }) })()
	local before = { speed = 1000, wins = 0, rebirths = 0, speedCarry = 0 }
	local plain = StatsService.CalculateSpeedGain(before, 10, {})
	local disco = StatsService.CalculateSpeedGain(before, 10, { disco = multiplier })
	local low = StatsService.CalculateSpeedGain(before, 10, { disco = 0.5 })
	assert(plain.ok and disco.ok and low.ok, "The gain accepts a disco factor")
	local plainAdded = plain.value.values.speed - before.speed
	local discoAdded = disco.value.values.speed - before.speed
	assert(math.abs(discoAdded - plainAdded * multiplier) < 1e-6, "On the pad the Speed gain is x" .. multiplier .. " (" .. plainAdded .. " -> " .. discoAdded .. ")")
	assert(low.value.values.speed - before.speed == plainAdded, "A pad never slows anyone")
	local bad = StatsService.CalculateSpeedGain(before, 10, { disco = 0 / 0 })
	assert(bad.ok == false, "A broken factor is refused, not applied")
	local bridge = fs.readFile("src/common/ServerScriptService/Progression/PlayerStatsBridge.luau")
	has(bridge, 'disco = attribute(player, "DiscoSpeedGainMultiplier"),', "The running loop reads the player's pad multiplier")
	print("PASS gain: running on the pad earns x" .. multiplier .. " Speed; broken or lower factors never hurt")
end

----------------------------------------------------------------------
-- 3. The HUD's [Disco] card
----------------------------------------------------------------------
do
	local hud = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(hud, 'clone.Name = "DiscoBuffCard"', "A Disco card among the boost cards")
	has(hud, 'applyCardVisuals(discoCard, ICON_DISCO_BUFF, "[Disco]", "x" .. tostring(discoMultiplier))', "It reads [Disco] with its multiplier")
	has(hud, "discoCard.Visible = false", "...and hides when the multiplier goes")
	has(hud, 'player:GetAttributeChangedSignal("DiscoSpeedGainMultiplier"):Connect(refreshBuffDisplay)', "It follows the multiplier as it changes")
	print("PASS HUD: a [Disco] card with its multiplier (x2, x100 dancing) during the party, gone after it")
end
