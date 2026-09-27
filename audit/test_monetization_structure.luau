--!strict
-- audit/test_monetization_structure.luau
-- Guards the SKU boundary that kept getting broken. Two separate purchases:
--   * the x2 PADS: one permanent gamepass (1941409601). Buy once, every x2 pad pays
--     double. It does not raise the Wins multiplier.
--   * the Wins LADDER: five developer products (x2..x32) that multiply every wins
--     reward. They do not unlock the x2 pads.
-- The per-claim pad product (3712435111) is retired: never prompted, receipts only.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function loadConfig()
	local stubInstance = {}
	stubInstance.GetAttribute = function() return nil end
	stubInstance.FindFirstChild = function() return nil end
	stubInstance.WaitForChild = function() return stubInstance end

	local env = {
		game = { GetService = function() return stubInstance end, PlaceId = 85065221510105 },
		workspace = stubInstance,
		Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, UDim2 = roblox.UDim2,
		table = table, math = math, string = string, os = os,
		ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring,
		type = type, typeof = typeof, next = next, select = select, pcall = pcall,
		error = error, assert = assert, print = function() end, warn = function() end,
	}
	return luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = env })()
end

local Config = loadConfig()

-- 1. The ladder is exactly the five dashboard developer products, in order.
local offered = Config.PermanentWinsMultiplierProducts or {}
local dashboardLadder = {
	{ id = 3710772221, multiplier = 2 },
	{ id = 3710772271, multiplier = 4 },
	{ id = 3710772305, multiplier = 8 },
	{ id = 3710772331, multiplier = 16 },
	{ id = 3710772380, multiplier = 32 },
}
assert(#offered == #dashboardLadder, "The Wins ladder must be the five dashboard products")
local previousPrice = 0
for index, rung in ipairs(dashboardLadder) do
	local product = offered[index]
	assert(tonumber(product.ProductId) == rung.id,
		("Ladder rung %d must be dashboard product %d"):format(index, rung.id))
	assert(tonumber(product.TargetMultiplier) == rung.multiplier,
		("Ladder rung %d must grant x%d"):format(index, rung.multiplier))
	assert(product.IsGamePass ~= true, "Ladder rungs are developer products: " .. tostring(product.Label))
	local price = tonumber(product.PriceRobux) or 0
	assert(price > previousPrice, "Ladder prices must strictly increase: " .. tostring(product.Label))
	previousPrice = price
end

-- 2. The x2 pads are the permanent gamepass, and it is not a ladder rung.
local padsPass = tonumber(Config.DoubleWinsPadGamePassId)
assert(padsPass == 1941409601, "The x2 pads gamepass id changed")
assert(tonumber(Config.TwoXVictoryGamePassId) == padsPass, "2X Victory and the x2 pads must be the same pass")
for _, product in ipairs(offered) do
	assert(tonumber(product.ProductId) ~= padsPass, "The x2 pads pass must not be sold as a ladder rung")
end

-- 3. The per-claim pad product is retired: registered for receipts, prompted nowhere.
assert(tonumber(Config.RetiredDoubleWinsPadProductId) == 3712435111, "Retired pad product id changed")
assert(Config.DoubleWinsPadProductId == nil,
	"DoubleWinsPadProductId must stay gone; every old read had an `or 3712435111` fallback")

local retired = Config.RetiredPermanentWinsMultiplierProducts or {}
assert(#retired >= 3, "Retired OG Wins products must stay listed for in-flight receipts")
for _, product in ipairs(retired) do
	for _, live in ipairs(offered) do
		assert(tonumber(live.ProductId) ~= tonumber(product.ProductId),
			"A retired Wins product is still being offered: " .. tostring(product.ProductId))
	end
end

local purchases = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
assert(string.find(purchases, "RetiredPermanentWinsMultiplierProducts", 1, true),
	"SpeedProductPurchases must still honour receipts for retired Wins products")
assert(string.find(purchases, "tonumber(Config.RetiredDoubleWinsPadProductId)", 1, true),
	"SpeedProductPurchases must still honour an in-flight receipt for the retired pad product")

local padService = fs.readFile("src/common/ServerScriptService/Services/DoubleWinsPad.luau")
assert(string.find(padService, "PromptGamePassPurchase(player, DoubleWinsPad.GamePassId)", 1, true),
	"The x2 pads must prompt the gamepass")
assert(not string.find(padService, "PromptProductPurchase", 1, true),
	"The x2 pads must never prompt a developer product again")

for _, path in ipairs({
	"src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau",
	"src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau",
	"src/worlds/World1/ServerScriptService/Gameplay/WinPads.server.luau",
}) do
	local source = fs.readFile(path)
	assert(not string.find(source, "3712435111", 1, true) and not string.find(source, "DoubleWinsPadProductId", 1, true),
		path .. " must not reference the retired pad product")
end

-- 4. Neither purchase leaks into the other.
local ladderGrant = string.match(purchases, "local function grantPermanentWinsMultiplierTransaction.-\nend\n")
assert(ladderGrant, "grantPermanentWinsMultiplierTransaction not found")
assert(not string.find(ladderGrant, "DoubleWinsPadUnlocked", 1, true),
	"Buying a ladder rung must not unlock the x2 pads")

local passJoin = string.match(purchases, "local function refreshDoubleWinsPassOwnership.-\nend\n")
assert(passJoin and not string.find(passJoin, "PermanentWinsMultiplier", 1, true),
	"Owning the x2 pads pass must not raise the Wins multiplier on join")
local perk = string.match(purchases, "grantPassPerkToTarget = function.-\nend\n")
assert(perk and not string.find(perk, "SetPermanentWinsMultiplier", 1, true),
	"A pass perk grant must not raise the Wins multiplier")

local projection = fs.readFile("src/common/ServerScriptService/Services/Stats/StatsProjection.luau")
assert(not string.find(projection, "if winsMult >= 2 then", 1, true),
	"The saved Wins multiplier must not project into an x2 pads unlock")

for _, product in ipairs(offered) do
	assert((tonumber(product.PriceRobux) or 0) >= 100,
		"A permanent Wins offer is priced like a consumable: " .. tostring(product.Label))
end

-- 5. Flight: gliding costs stamina, and both sides enforce it.
assert((tonumber(Config.AbilityFlightGlideDrainPercentPerSecond) or 0) > 0,
	"Gliding must cost stamina or a single climb crosses a whole stage")
assert((tonumber(Config.AbilityFlightDrainPercentPerSecond) or 0) > 0,
	"The powered climb must cost stamina")
assert(Config.AbilityFlightMinimumStaminaToPower == nil,
	"The flat lift-off threshold is retired; it locked small suits out of flight")

-- The drain itself lives in Shared.FlightStamina; audit/test_flight_balance.luau
-- simulates it. Here we only pin the wiring.
local bootstrap = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
assert(string.find(bootstrap, "FlightStamina.Step", 1, true),
	"Bootstrap must drain stamina through Shared.FlightStamina")
local flightService = fs.readFile("src/common/ServerScriptService/Core/Abilities/FlightService.luau")
assert(string.find(flightService, "FlightStamina.GlideDrainPerSecond", 1, true),
	"FlightService must end flight when stamina is exhausted")
assert(string.find(flightService, "FlightStamina.MinimumToPower", 1, true),
	"FlightService must gate lift-off on a share of the player's own bar")
for _, world in ipairs({ "World1", "World2" }) do
	local client = fs.readFile(string.format(
		"src/worlds/%s/StarterPlayer/StarterPlayerScripts/Movement/%sFlightAbility.client.luau", world, world))
	assert(string.find(client, "FlightStamina.GlideDrainPerSecond", 1, true),
		world .. " flight client must stop flying once stamina runs out")
	assert(string.find(client, "FlightStamina.MinimumToPower", 1, true),
		world .. " flight client must gate lift-off on a share of the player's own bar")
end

print("PASS Wins SKUs: x2 pads gamepass + five-product Wins ladder, kept apart; retired products receipt-only")
print("PASS Flight: powered drain raised and gliding now costs stamina on client and server")
print("ALL MONETIZATION STRUCTURE CHECKS PASSED")
