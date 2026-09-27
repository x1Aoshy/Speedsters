-- audit/test_fable_teleport_price.luau  (2026-09-20)
-- The exploit: a stage teleport lands the player beside that stage's Win and x2 pads, a pad pays
-- and sends them home, and the trip cost LESS than the pad paid (the trip was priced with the
-- damped ladder formula, base * permanent ^ 0.5, while the pad pays base * every multiplier,
-- doubled on the x2 pad). Players looped teleport -> pad -> teleport for free Wins, worst in
-- World 3. This proves, with the real Config of each world, the real WinsMath and the real
-- pricing function of TeleportSystem:
--   1. the old price really was below the payout (so the test would have caught it);
--   2. the new price is above what the arrival pads pay, in the three worlds, for every stage,
--      every ladder rung, VIP, potion, confetti, server boost and the x2 pads pass;
--   3. TeleportSystem prices with the same multiplier RewardPadClaims pays with, refuses a
--      stale quote, and refunds a recovered trip that was paid at another world's price;
--   4. nothing else moved: Flight and Sonic Burst keep the damped ladder price.
-- Pass "places" to check the three places carry the scripts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local C = "src/common/"
local WINSMATH = C .. "ReplicatedStorage/Shared/WinsMath.luau"
local SYSTEM = C .. "ServerScriptService/Worlds/TeleportSystem.server.luau"
local CLIENT = C .. "StarterPlayer/StarterPlayerScripts/UI/TeleportController.client.luau"
local CONFIG = C .. "ReplicatedStorage/Shared/Config.luau"
local CLAIMS = C .. "ServerScriptService/Services/RewardPadClaims.luau"
local W1_PADS = "src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau"
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end
for _, path in { WINSMATH, SYSTEM, CLIENT, CONFIG } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. ": " .. tostring(problem))
end

local function loadWith(path, placeId)
	local stub = {}
	stub.GetAttribute = function() return nil end
	-- World 1 knows itself by its map (Workspace.neworld1); the other two by their place id.
	stub.FindFirstChild = function(_, name) return if name == "neworld1" and placeId == 85065221510105 then stub else nil end
	stub.WaitForChild = function() return stub end
	return luau.load(fs.readFile(path), { environment = {
		game = { GetService = function() return stub end, PlaceId = placeId }, workspace = stub,
		Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame, Enum = rb.Enum, UDim2 = rb.UDim2,
		table = table, math = math, string = string, os = os, ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring,
		type = type, typeof = typeof, next = next, select = select, pcall = pcall, error = error, assert = assert,
		print = function() end, warn = function() end } })()
end
local WinsMath = loadWith(WINSMATH, 0)

-- What the arrival pads of each world pay at x1, and what the trip costs at x1.
local worlds = {}
do
	local w1 = loadWith(CONFIG, 85065221510105)
	local w2 = loadWith(CONFIG, 116359653478954)
	local w3 = loadWith(CONFIG, 128432111599629)
	assert(w1.IsNewWorld1Map == true and w2.IsWorld2Place == true and w3.IsWorld3Place == true, "the three Configs did not load as the three worlds")
	local padsSource = fs.readFile(W1_PADS)
	local block = assert(padsSource:match("local STAGE_REWARDS = (%b{})"), "World 1's pad rewards not found")
	local w1Rewards = luau.load("return " .. block)()
	worlds = {
		{ Name = "World 1", Options = w1.TeleportStageOptions, Rewards = w1Rewards, Exponent = w1.ProgressionPriceMultiplierExponent },
		{ Name = "World 2", Options = w2.TeleportStageOptions, Rewards = w2.World2StageWinRewards, Exponent = w2.ProgressionPriceMultiplierExponent },
		{ Name = "World 3", Options = w3.TeleportStageOptions, Rewards = w3.World3StageWinRewards, Exponent = w3.ProgressionPriceMultiplierExponent },
	}
	for _, world in worlds do
		assert(#world.Options >= 9, world.Name .. " offers " .. #world.Options .. " trips")
		for _, option in world.Options do
			local reward = assert(world.Rewards[option.Stage], world.Name .. " stage " .. option.Stage .. " has no pad reward")
			-- (World 2 rounds its trips to 25,000: Stage 3 is 100,000 against a 75,000 pad, 1.33 times.)
			assert(option.WinsCost >= reward * 1.3, ("%s stage %d: the base trip (%d) must stay well above the base pad reward (%d)"):format(world.Name, option.Stage, option.WinsCost, reward))
		end
	end
end

-- The pad's side, exactly as RewardPadClaims pays: floor(reward * multiplier), the x2 pad on a doubled reward.
local function padPays(reward, total, doublePads)
	local normal = math.floor(reward * total)
	local double = if doublePads then math.floor(reward * WinsMath.PadDoubleMultiplier * total) else 0
	return math.max(normal, double)
end
do
	local claims = fs.readFile(CLAIMS)
	assert(claims:find("local grantedAmount = math.floor(reward * multiplier)", 1, true) and claims:find("_G.SpeedsterGetWinsMultiplier", 1, true),
		"RewardPadClaims no longer pays floor(reward * SpeedsterGetWinsMultiplier): revisit the trip price")
end

-- 1. The bug, reproduced with the old formula.
do
	local world3 = worlds[3]
	local stage10
	for _, option in world3.Options do
		if option.Stage == 10 then stage10 = option end
	end
	local oldPrice = WinsMath.GetProgressionPrice(stage10.WinsCost, 32, world3.Exponent)
	local paid = padPays(world3.Rewards[10], 32, false)
	assert(oldPrice < paid, "the old price was not below the payout?")
	print(("  World 3, Stage 10, x32: the old trip cost %s and its pad paid %s (%s on the x2 pad): +%s Wins per loop")
		:format(oldPrice, paid, padPays(world3.Rewards[10], 32, true), paid - oldPrice))
	local loops = 0
	for _, world in worlds do
		for _, option in world.Options do
			for _, rung in { 1, 2, 4, 8, 16, 32 } do
				for _, doublePads in { false, true } do
					if WinsMath.GetProgressionPrice(option.WinsCost, rung, world.Exponent) < padPays(world.Rewards[option.Stage], rung, doublePads) then
						loops += 1
					end
				end
			end
		end
	end
	assert(loops > 100, "expected the old formula to lose money in most cases, found " .. loops)
	pass(("the bug is real: with the old formula %d of %d stage/rung/x2-pass cases paid more than the trip cost, before any VIP, potion or boost"):format(loops, 3 * 9 * 6 * 2))
end

-- 2. The new price, against everything a pad can pay with.
do
	local cases, tightest = 0, math.huge
	for _, world in worlds do
		for _, option in world.Options do
			local reward = world.Rewards[option.Stage]
			for _, rung in { 1, 2, 4, 8, 16, 32 } do
				for _, vip in { 1, 1.5, 2 } do
					for _, timed in { 1, 2, 4, 8 } do -- potion x confetti x server boost
						for _, doublePads in { false, true } do
							local total = rung * vip * timed
							local price = WinsMath.GetStageTripPrice(option.WinsCost, total, doublePads)
							local pays = padPays(reward, total, doublePads)
							assert(price > pays, ("%s stage %d at x%g%s: the trip costs %d and the pad pays %d"):format(
								world.Name, option.Stage, total, doublePads and " + x2 pads" or "", price, pays))
							tightest = math.min(tightest, price / pays)
							cases += 1
						end
					end
				end
			end
		end
	end
	assert(tightest >= 1.3, "the trip must stay at least 1.3 times the arrival pad, got " .. tightest)
	-- Edges.
	assert(WinsMath.GetStageTripPrice(0, 5, true) == 0 and WinsMath.GetStageTripPrice(nil, 5, true) == 0 and WinsMath.GetStageTripPrice(-5, 5, true) == 0)
	assert(WinsMath.GetStageTripPrice(100, nil, false) == 100 and WinsMath.GetStageTripPrice(100, 0.2, false) == 100 and WinsMath.GetStageTripPrice(100, 0 / 0, false) == 100)
	assert(WinsMath.GetStageTripPrice(100, 1.015, false) == 102, "a fractional price rounds up, never down")
	assert(WinsMath.GetStageTripPrice(1e15, 1e6, true) == 9007199254740991, "an out-of-range price must be unaffordable, not free")
	local owner = { GetAttribute = function(_, name) return name == "TwoXVictoryOwned" end }
	local other = { GetAttribute = function() return nil end }
	assert(WinsMath.OwnsDoublePads(owner) == true and WinsMath.OwnsDoublePads(other) == false and WinsMath.OwnsDoublePads(nil) == false)
	local padService = fs.readFile(C .. "ServerScriptService/Services/DoubleWinsPad.luau")
	for _, name in WinsMath.DoublePadOwnedAttributes do
		assert(padService:find('"' .. name .. '"', 1, true), "DoubleWinsPad no longer marks owners with " .. name)
	end
	pass(("the new price: %d cases (3 worlds x 9 stages x 6 rungs x VIP x timed boosts x x2 pads), the trip always costs at least %.2f times what its arrival pad pays"):format(cases, tightest))
end

-- 3. TeleportSystem itself.
do
	local system = fs.readFile(SYSTEM)
	assert(not system:find("GetProgressionPrice", 1, true), "TeleportSystem still prices trips with the damped ladder formula")
	local a = assert(system:find("local function currentCosts(player)", 1, true))
	local b = assert(system:find("\nend\n", a, true))
	local globals = {}
	local options = {}
	for _, option in worlds[3].Options do
		options[option.Stage] = option
	end
	local currentCosts = luau.load("local optionsByStage, WinsMath = ...\n" .. system:sub(a, b + 4) .. "\nreturn currentCosts", { environment = {
		_G = globals, type = type, tonumber = tonumber, pairs = pairs, math = math } })(options, WinsMath)
	local function player(attributes)
		return { GetAttribute = function(_, name) return attributes[name] end }
	end
	-- The pads' resolver, when it is there; the permanent one only as a fallback; none at all: x1.
	local costs, shown = currentCosts(player({}))
	assert(shown == 1 and costs[10] == options[10].WinsCost and costs[2] == options[2].WinsCost)
	globals.SpeedsterGetPermanentWinsMultiplier = function() return 4 end
	assert(currentCosts(player({}))[10] == options[10].WinsCost * 4)
	globals.SpeedsterGetWinsMultiplier = function() return 4 * 2 * 2 end -- x4 rung, a potion, a server boost
	costs, shown = currentCosts(player({}))
	assert(shown == 16 and costs[10] == options[10].WinsCost * 16, "the trip must follow the full multiplier the pads pay with")
	assert(currentCosts(player({ DoubleWinsPadUnlocked = true }))[10] == options[10].WinsCost * 32, "an owner of the x2 pads is priced against the x2 pad")
	assert(costs[10] > padPays(worlds[3].Rewards[10], 16, false))
	for _, broken in { 0 / 0, math.huge, 0.5, "x" } do
		globals.SpeedsterGetWinsMultiplier = function() return broken end
		local none = currentCosts(player({}))
		assert(next(none) == nil, "a broken multiplier must sell no trip at all")
	end
	-- The quote handshake and the recovered trip.
	for _, needed in { "if displayedCost~=cost then", 'kind = "BeginStageTeleport"', "recovered = true", "fairlyPaid = price ~= nil and trip.cost >= price",
		"if trip.world == WORLD and fairlyPaid then", "refund = not moved", '"PotionWinsExpireUnix"', '"DoubleWinsPadUnlocked"', '"ServerWinsBoostExpiresUnix"' } do
		assert(system:find(needed, 1, true), "TeleportSystem lost: " .. needed)
	end
	local client = fs.readFile(CLIENT)
	assert(client:find('TeleportAction:FireServer("Wins", stageNum, quotedCosts[stageNum])', 1, true) and client:find("message.Costs", 1, true),
		"the panel must buy at the server's quote")
	assert(not client:find("GetProgressionPrice", 1, true) and not client:find("GetStageTripPrice", 1, true), "the panel must not price trips itself")
	pass("TeleportSystem: same multiplier as the pads, x2 pads priced in, broken multiplier sells nothing, stale quotes refused, a recovered trip paid below this world's price is refunded")
end

-- 4. The one-off unlocks keep their damped price.
do
	for _, path in { C .. "ServerScriptService/Core/Abilities/FlightService.luau", C .. "ServerScriptService/Core/Abilities/SonicBurstService.server.luau" } do
		local source = fs.readFile(path)
		assert(source:find("GetProgressionPrice", 1, true) and not source:find("GetStageTripPrice", 1, true), path .. " changed its pricing")
	end
	assert(WinsMath.GetProgressionPrice(1000000, 32, 0.5) == math.ceil(1000000 * 32 ^ 0.5))
	pass("Flight and Sonic Burst keep the damped ladder price: they are bought once and open no loop")
end

if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
		local dm = rb.deserializePlace(fs.readFile(place[2]))
		for _, source in { WINSMATH, SYSTEM, CLIENT, CONFIG } do
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
	end
	pass("the three places carry the new WinsMath, TeleportSystem, teleport panel and Config")
end
print(("ALL PASSED (%d groups)"):format(passed))
