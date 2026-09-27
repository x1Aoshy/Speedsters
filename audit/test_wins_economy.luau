--!strict
-- audit/test_wins_economy.luau
-- Pins the shape of the Wins economy against the ladder.
--
-- The ladder (x2..x32) multiplies income. The unlock pool it spends against is
-- fixed and small, so without damping the top rungs buy the whole game in about
-- one lap. These assertions are the guard rail: progression unlocks must scale
-- with the permanent multiplier, cosmetics must NOT, and every rung must still
-- be a real improvement over the one below it.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local failures = 0
local checks = 0

local function check(label: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print("ok   " .. label)
	else
		failures += 1
		print("FAIL " .. label .. (detail and ("  -- " .. detail) or ""))
	end
end

local function baseEnv()
	local stubInstance = {}
	stubInstance.GetAttribute = function() return nil end
	stubInstance.FindFirstChild = function() return nil end
	stubInstance.WaitForChild = function() return stubInstance end

	return {
		game = { GetService = function() return stubInstance end, PlaceId = 85065221510105 },
		workspace = stubInstance,
		Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, UDim2 = roblox.UDim2,
		table = table, math = math, string = string, os = os,
		ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring,
		type = type, typeof = typeof, next = next, select = select, pcall = pcall,
		error = error, assert = assert, print = function() end, warn = function() end,
	}
end

local function loadModule(path: string)
	return luau.load(fs.readFile(path), { environment = baseEnv() })()
end

local Config = loadModule("src/common/ReplicatedStorage/Shared/Config.luau")
local WinsMath = loadModule("src/common/ReplicatedStorage/Shared/WinsMath.luau")
local Catalog = loadModule("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau")

-- ---------------------------------------------------------------- earn rates

-- World 1 pads live in the world script, not Config, so they are read from source.
local world1Source = fs.readFile(
	"src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau"
)

local world1StageTotal = 0
local world1StageCount = 0
do
	local block = world1Source:match("local STAGE_REWARDS = {(.-)}")
	assert(block, "STAGE_REWARDS table not found in NewWorld1ManualStagePads")
	for value in block:gmatch("%[%d+%]%s*=%s*(%d+)") do
		world1StageTotal += tonumber(value) :: number
		world1StageCount += 1
	end
end
local world1FinalReward = tonumber(world1Source:match("local FINAL_WIN_REWARD = (%d+)")) or 0
local world1Lap = world1StageTotal + world1FinalReward

check(
	"World 1 exposes 11 stage pads",
	world1StageCount == 11,
	("found %d"):format(world1StageCount)
)
check(
	"World 1 lap pays 1,157,020",
	world1Lap == 1157020,
	("stages %d + final %d = %d"):format(world1StageTotal, world1FinalReward, world1Lap)
)

local world2Lap = 0
for _, reward in pairs(Config.World2StageWinRewards) do
	world2Lap += reward
end
world2Lap += Config.World2FinalWinReward
check(
	"World 2 lap pays 2,985,000",
	world2Lap == 2985000,
	("got %d"):format(world2Lap)
)

-- -------------------------------------------------------------- the fixed pool

-- The original shop (World 1 and 2 cosmetics) stays the fixed pool the ladder is tuned
-- against. World 3's cosmetics are a separate, much deeper sink on top of it.
local cosmeticPool = 0
local world3Pool = 0
local blackMultiplier = { Aura = 0, Trail = 0 }
for cosmeticType, list in { Aura = Catalog.Auras, Trail = Catalog.Trails } do
	for _, entry in ipairs(list) do
		if entry.ShopEnabled == true then
			if entry.World == 3 then
				world3Pool += tonumber(entry.WinsCost) or 0
			else
				cosmeticPool += tonumber(entry.WinsCost) or 0
				blackMultiplier[cosmeticType] = math.max(blackMultiplier[cosmeticType], tonumber(entry.SpeedMultiplier) or 0)
			end
		end
	end
end
local flightCost = tonumber(Config.AbilityFlightWinsCost) or 0
local fixedPool = cosmeticPool + flightCost

check(
	"original shop cosmetics total 22,222,220 Wins",
	cosmeticPool == 22222220,
	("got %d"):format(cosmeticPool)
)
check(
	"fixed unlock pool is 47,222,220 Wins",
	fixedPool == 47222220,
	("got %d"):format(fixedPool)
)

-- World 3's cosmetics: every one costs at least a World 3 lap's worth of Wins at x1 (the
-- top of World 2's shop is 10M), and each is a modest step above Black, never a leap:
-- an aura and a trail multiply each other, so 3x Black on both is already 9x.
local world3Lap = 0
for _, reward in pairs(Config.World3StageWinRewards) do
	world3Lap += reward
end
world3Lap += Config.World3FinalWinReward
-- Stages 9 (6.5M) and 10 (8M) came with the final desert map (2026-09-18).
check("World 3 lap pays 41,000,000", world3Lap == 41000000, ("got %d"):format(world3Lap))
for cosmeticType, list in { Aura = Catalog.Auras, Trail = Catalog.Trails } do
	local previousCost, previousMultiplier = 0, blackMultiplier[cosmeticType]
	for _, entry in ipairs(Catalog.GetSortedShopEntries(cosmeticType)) do
		if entry.World == 3 then
			local cost = tonumber(entry.WinsCost) or 0
			local multiplier = tonumber(entry.SpeedMultiplier) or 0
			check(("%s costs at least 20M Wins"):format(entry.DisplayName), cost >= 20000000, tostring(cost))
			check(("%s is dearer and stronger than the one before"):format(entry.DisplayName), cost > previousCost and multiplier > previousMultiplier)
			check(("%s stays within 3x Black"):format(entry.DisplayName), multiplier <= 3 * blackMultiplier[cosmeticType], tostring(multiplier))
			previousCost, previousMultiplier = cost, multiplier
		end
	end
	for _, entry in ipairs(list) do
		if entry.Exclusive ~= nil then
			check(("%s is never sold"):format(entry.DisplayName), entry.ShopEnabled ~= true and (tonumber(entry.WinsCost) or 0) == 0 and entry.RobuxPurchaseId == nil)
		end
	end
end
check(
	"World 3's shop is a deep sink: at least 100 World 3 laps at x1",
	world3Pool >= 100 * world3Lap,
	("%.1f laps"):format(world3Pool / world3Lap)
)

-- ------------------------------------------------------------------- damping

local exponent = Config.ProgressionPriceMultiplierExponent
check(
	"progression price exponent is configured in (0, 1)",
	type(exponent) == "number" and exponent > 0 and exponent < 1,
	tostring(exponent)
)

local function progressionLaps(baseCost: number, tier: number): number
	local price = WinsMath.GetProgressionPrice(baseCost, tier, exponent)
	return price / (world1Lap * tier)
end

-- A rung must always be a real improvement, never a free pass.
local previousFlightLaps = math.huge
for _, tier in { 1, 2, 4, 8, 16, 32 } do
	local laps = progressionLaps(flightCost, tier)
	check(
		("x%d makes Flight strictly cheaper in laps than the rung below"):format(tier),
		laps < previousFlightLaps,
		("%.2f laps vs %.2f"):format(laps, previousFlightLaps)
	)
	previousFlightLaps = laps
end

check(
	"x1 Flight still costs over 20 laps",
	progressionLaps(flightCost, 1) > 20,
	("%.2f laps"):format(progressionLaps(flightCost, 1))
)
check(
	"x32 Flight still costs more than 2 laps",
	progressionLaps(flightCost, 32) > 2,
	("%.2f laps"):format(progressionLaps(flightCost, 32))
)
check(
	"x32 reaches Flight between 4x and 8x faster than x1",
	(function()
		local ratio = progressionLaps(flightCost, 1) / progressionLaps(flightCost, 32)
		return ratio > 4 and ratio < 8
	end)(),
	("%.2fx"):format(progressionLaps(flightCost, 1) / progressionLaps(flightCost, 32))
)

-- The deepest World 2 teleport, same rule.
local deepestTeleport = 0
for _, cost in pairs(Config.World2TeleportWinsCosts) do
	if cost > deepestTeleport then
		deepestTeleport = cost
	end
end
-- Stage 10 leads to the finish (1,000,000), not to its own 500,000 pad: at 725,000 it left a
-- profit for running a single stage, so since 2026-09-20 it costs 1.5 finishes.
check(
	"deepest World 2 teleport (Stage 10) is 1,500,000 base",
	deepestTeleport == 1500000 and Config.World2TeleportWinsCosts[10] == deepestTeleport,
	("got %d"):format(deepestTeleport)
)
check(
	"the World 2 Stage 10 trip costs more than the finish it leads to, x2 pad included",
	(function()
		for _, tier in { 1, 2, 4, 8, 16, 32 } do
			for _, doublePads in { false, true } do
				local finishPays = math.floor(Config.World2FinalWinReward * (if doublePads then 2 else 1) * tier)
				if WinsMath.GetStageTripPrice(deepestTeleport, tier, doublePads) <= finishPays then
					return false
				end
			end
		end
		return true
	end)()
)
check(
	"the other World 2 trips keep their price (1.45 x their pad, rounded to 25,000)",
	Config.World2TeleportWinsCosts[9] == 550000 and Config.World2TeleportWinsCosts[2] == 75000
)
-- Stage teleports left the damped formula on 2026-09-20: a trip lands beside pads that pay
-- with the full multiplier, so a damped trip cost less than its arrival pad paid and players
-- looped teleport -> pad for free Wins (audit/test_fable_teleport_price has the whole proof).
-- A trip now scales with everything the pad pays with, so it costs the same in lap terms on
-- every rung, and never less than the pad beside it.
check(
	"x32 pays 32 times the Wins of x1 for the deepest teleport",
	WinsMath.GetStageTripPrice(deepestTeleport, 32, false) == deepestTeleport * 32
)
check(
	"the deepest teleport always costs more than its arrival pad pays, x2 pad included",
	(function()
		for _, tier in { 1, 2, 4, 8, 16, 32 } do
			for _, doublePads in { false, true } do
				local pays = math.floor(Config.World2StageWinRewards[10] * (if doublePads then 2 else 1) * tier)
				if WinsMath.GetStageTripPrice(deepestTeleport, tier, doublePads) <= pays then
					return false
				end
			end
		end
		return true
	end)()
)

-- -------------------------------------------------------- helper edge cases

check("zero base cost prices at zero", WinsMath.GetProgressionPrice(0, 32, exponent) == 0)
check("negative base cost prices at zero", WinsMath.GetProgressionPrice(-5, 32, exponent) == 0)
check(
	"exponent 0 restores flat pricing",
	WinsMath.GetProgressionPrice(725000, 32, 0) == 725000
)
check(
	"exponent 1 restores the old linear behaviour",
	WinsMath.GetProgressionPrice(725000, 32, 1) == 725000 * 32
)
check(
	"a multiplier below 1 never discounts",
	WinsMath.GetProgressionPrice(725000, 0.25, exponent) == 725000
)
check("nan multiplier falls back to base", WinsMath.GetProgressionPrice(725000, 0 / 0, exponent) == 725000)
check("nil multiplier falls back to base", WinsMath.GetProgressionPrice(725000, nil, exponent) == 725000)
check(
	"nil exponent uses the module default",
	WinsMath.GetProgressionPrice(725000, 32, nil)
		== WinsMath.GetProgressionPrice(725000, 32, WinsMath.DefaultProgressionPriceExponent)
)
check("prices are whole Wins", WinsMath.GetProgressionPrice(725000, 3, exponent) % 1 == 0)

-- GetProgressionPriceFor must read only the PERMANENT multiplier: a potion is a
-- timed boost, and pricing against it would move an unlock's price for 10 minutes.
local playerStub = {
	GetAttribute = function(_self: any, name: string): any
		if name == "PermanentWinsMultiplier" then return 16 end
		if name == "PotionWinsMultiplier" then return 2 end
		if name == "PotionWinsExpireUnix" then return os.time() + 600 end
		return nil
	end,
}
check(
	"per-player pricing ignores timed potion boosts",
	WinsMath.GetProgressionPriceFor(flightCost, playerStub, exponent)
		== WinsMath.GetProgressionPrice(flightCost, 16, exponent)
)

-- --------------------------------------------------- cosmetics are NOT damped

local cosmeticCallSites = 0
for _, path in {
	"src/common/ServerScriptService/Economy/AuraShopSystem.server.luau",
	"src/common/ServerScriptService/Economy/TrailShopSystem.server.luau",
} do
	local source = fs.readFile(path)
	if source:find("GetProgressionPrice", 1, true) then
		cosmeticCallSites += 1
	end
end
check(
	"cosmetic shops do not damp their prices",
	cosmeticCallSites == 0,
	("%d shop(s) call GetProgressionPrice"):format(cosmeticCallSites)
)

-- ----------------------------------------- the quote and the charge must match

local flightSource = fs.readFile("src/common/ServerScriptService/Core/Abilities/FlightService.luau")
check(
	"FlightService quotes the damped price",
	flightSource:find("WinsCost = flightWinsCost(player)", 1, true) ~= nil
)
check(
	"FlightService charges the damped price",
	flightSource:find("cost=flightWinsCost(player)", 1, true) ~= nil
)
check(
	"FlightService no longer charges the raw constant",
	flightSource:find("cost=WINS_COST", 1, true) == nil
)
-- Two scripts define _G.SpeedsterGetPermanentWinsMultiplier and they disagree:
-- PlayerStats reads the attribute alone, PlayerStatsBridge takes
-- math.max(attribute, persisted profile). Flight must price against that shared
-- getter, exactly like TeleportSystem, or a player who joins and buys before the
-- attribute replicates gets Flight at the x1 price.
check(
	"FlightService prices against the canonical permanent-multiplier getter",
	flightSource:find("pcall(_G.SpeedsterGetPermanentWinsMultiplier, player)", 1, true) ~= nil
		and flightSource:find("WinsMath.GetProgressionPrice(WINS_COST, multiplier", 1, true) ~= nil
)

local teleportSource = fs.readFile("src/common/ServerScriptService/Worlds/TeleportSystem.server.luau")
check(
	"TeleportSystem prices through WinsMath, against what the arrival pads pay",
	teleportSource:find("WinsMath.GetStageTripPrice(baseCost, multiplier, doublePads)", 1, true) ~= nil
		and teleportSource:find("GetProgressionPrice", 1, true) == nil
)
check(
	"TeleportSystem has no pricing arithmetic of its own",
	teleportSource:find("math.ceil(baseCost * multiplier)", 1, true) == nil
)

-- ---------------------------------------------------------------------- done

-- ------------------------------------------------------ the core loop holds

-- The Spin Wheel pays Wins as a share of a lap of the player's world: its laps must be
-- the worlds' real ones.
local laps = Config.SpinWheel and Config.SpinWheel.LapWins or {}
check("Spin Wheel knows World 1's lap", laps.World1 == world1Lap, tostring(laps.World1))
check("Spin Wheel knows World 2's lap", laps.World2 == world2Lap, tostring(laps.World2))
check("Spin Wheel knows World 3's lap", laps.World3 == world3Lap, tostring(laps.World3))

-- Nothing new lets a player skip the run from World 1 to World 3: World 3 still needs its
-- level and rebirths (rebirths reset Speed and need ever more Levels, earned by running),
-- World 3's cosmetics cost many World 1 laps, and the Spin Wheel's exclusives stay within
-- reach of what Black and the paid limited already give.
check("World 3 still needs Level 200", Config.World3UnlockLevel == 200, tostring(Config.World3UnlockLevel))
check("World 3 still needs 15 rebirths", Config.World3UnlockRebirths == 15, tostring(Config.World3UnlockRebirths))
check("Rebirths still need Level 5, then 15 more each", Config.RebirthFirstLevelRequired == 5 and Config.RebirthLevelStep == 15)
local cheapestWorld3 = math.huge
for _, list in { Catalog.Auras, Catalog.Trails } do
	for _, entry in ipairs(list) do
		if entry.World == 3 and entry.ShopEnabled == true then
			cheapestWorld3 = math.min(cheapestWorld3, tonumber(entry.WinsCost) or 0)
		end
	end
end
check(
	"World 3's cheapest cosmetic costs over 15 World 1 laps at x1",
	cheapestWorld3 / world1Lap > 15,
	("%.1f laps"):format(cheapestWorld3 / world1Lap)
)
local aura67 = Catalog.GetEntry("Aura", "Aura67")
check("Aura 67 (a wheel prize) is at most 2x Black", aura67 ~= nil and aura67.SpeedMultiplier <= 2 * blackMultiplier.Aura, tostring(aura67 and aura67.SpeedMultiplier))
local suits = Config.SuitSpeedGainMultipliers or {}
check(
	"Tung Tung (a wheel prize) sits below the paid limited",
	suits.TungTungSuit ~= nil and (suits.DarkZonicSuit == nil or suits.TungTungSuit < suits.DarkZonicSuit),
	tostring(suits.TungTungSuit)
)
-- Two free spins a day pay, on average, well under half a lap of Wins in any world.
local wheelShares = { Small = Config.SpinWheel.SmallLapShare, Large = Config.SpinWheel.LargeLapShare }
local Wheel = loadModule("src/common/ReplicatedStorage/Shared/SpinWheelCatalog.luau")
for world, lap in { World1 = world1Lap, World2 = world2Lap, World3 = world3Lap } do
	local perSpin = 0
	for _, segment in ipairs(Wheel.Segments) do
		if segment.Kind == "Wins" then
			perSpin += Wheel.WinsAmount(segment.Tier, 200, lap, wheelShares) * segment.Weight / 100
		end
	end
	local spinsPerDay = 86400 / Config.SpinWheel.FreeSpinWindowSeconds
	check(
		("%s: a day of free spins pays under half a lap"):format(world),
		perSpin * spinsPerDay < lap * 0.5,
		("%.2f laps"):format(perSpin * spinsPerDay / lap)
	)
end

print("")
print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("test_wins_economy: %d failing check(s)"):format(failures))
end
print("WINS ECONOMY OK")
