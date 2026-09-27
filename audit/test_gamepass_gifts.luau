-- test_gamepass_gifts.luau
-- Game passes are gifted through a developer product per pass. The receipt saves the
-- pass on the recipient's profile, and everything that checks ownership accepts it.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function read(path)
	return fs.readFile(path)
end

-- 1. GiftedPasses: the commands a gift writes, and reading them back from a profile.
local Config = {
	AbilityFlightGamePassId = 1978623069,
	DoubleWinsPadGamePassId = 1941409601,
	GamePassGiftProducts = {
		{ PassId = 1941409601, Name = "2x Wins Pads", ProductId = 111 },
		{ PassId = 1903494497, Name = "VIP", ProductId = nil },
	},
}
local profileUpgrades = { "Flight", "GiftedPass:1903494497", "GiftedPass:1941409601", "__AbilityEquipped_Flight" }
local fakeDataService = {
	GetHandle = function()
		return {}
	end,
	Inspect = function()
		return { ok = true, value = { profile = { OwnedUpgrades = profileUpgrades } } }
	end,
}
local function service(name)
	return { WaitForChild = function(_, child)
		return service(child)
	end, Name = name }
end
local modulesByName = { Config = Config, DataService = fakeDataService }
local GiftedPasses = luau.load(read("src/common/ServerScriptService/Services/Monetization/GiftedPasses.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, name)
			return service(name)
		end },
		require = function(object)
			return assert(modulesByName[object.Name], "unexpected require " .. tostring(object.Name))
		end,
	}, { __index = _G }),
})()

local function hasCommand(commands, upgradeId)
	for _, command in commands do
		if command.kind == "GrantUpgrade" and command.upgradeId == upgradeId then
			return true
		end
	end
	return false
end
local padCommands = GiftedPasses.Commands(1941409601)
assert(hasCommand(padCommands, "GiftedPass:1941409601") and hasCommand(padCommands, "TwoXVictory"),
	"A gifted x2 pads pass saves the gift and the TwoXVictory upgrade the projection already unlocks")
local flightCommands = GiftedPasses.Commands(1978623069)
assert(hasCommand(flightCommands, "GiftedPass:1978623069") and hasCommand(flightCommands, "Flight"),
	"A gifted Flight pass saves the Flight upgrade")
local vipCommands = GiftedPasses.Commands(1903494497)
assert(#vipCommands == 1 and hasCommand(vipCommands, "GiftedPass:1903494497"), "Other passes save only the gift marker")
assert(GiftedPasses.EntryForProduct(111).PassId == 1941409601, "Gift product ids resolve to their pass")
assert(GiftedPasses.EntryForProduct(0) == nil, "Unset products never match")

local player = { UserId = 7, GetAttribute = function(_, name)
	return name == "DataLoaded"
end }
assert(GiftedPasses.Has(player, 1903494497) and not GiftedPasses.Has(player, 1941060529), "Has reads the saved gift markers")
local listed = GiftedPasses.List(player)
table.sort(listed)
assert(#listed == 2 and listed[1] == 1903494497 and listed[2] == 1941409601, "List returns every gifted pass id")
local notLoaded = { UserId = 8, GetAttribute = function()
	return false
end }
assert(not GiftedPasses.Has(notLoaded, 1903494497) and #GiftedPasses.List(notLoaded) == 0, "Nothing is read before the data loads")
print("PASS GiftedPasses: gift commands, product lookup, and reading saved gifts")

-- 2. The gift commands persist like any receipt.
do
	local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
	local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
	local now = 6000000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local store = Adapter.CreateMock({ Player_55 = { Version = 306, Speed = 1, Wins = 0 } })
	local actor = Actor.new({ userId = 55, sessionId = "gift-a", storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok)
	local request = { operationId = "receipt:gift-1", receiptId = "gift-1", fingerprint = "111", commands = padCommands }
	assert(actor:Commit(opened.value, request).kind == "Committed")
	assert(actor:Commit(opened.value, request).kind == "AlreadyCommitted", "A repeated receipt grants once")
	now += 10
	assert(actor:Release(opened.value).kind == "Released")
	local again = Actor.new({ userId = 55, sessionId = "gift-b", storeAdapter = store, clock = clock })
	local reopened = again:Open()
	assert(reopened.ok)
	local upgrades = again:Inspect(reopened.value).value.profile.OwnedUpgrades
	assert(table.find(upgrades, "GiftedPass:1941409601") and table.find(upgrades, "TwoXVictory"), "The gifted pass survives a rejoin")
	print("PASS gift receipts persist on the recipient and grant exactly once")
end

-- 3. Wiring.
do
	local purchases = read("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	assert(string.find(purchases, 'productsById[productId] = { Kind = "GamePassGift", Data = entry }', 1, true),
		"Gift products from Config.GamePassGiftProducts must be registered receipts")
	assert(string.find(purchases, 'elseif entry.Kind == "GamePassGift" then', 1, true)
		and string.find(purchases, "GiftedPasses.Commands(passId)", 1, true),
		"A gift receipt writes GiftedPasses.Commands in the receipt transaction")
	assert(string.find(purchases, 'GiftContextRequest:FireClient(player,requestId,false,"Owned")', 1, true),
		"A pass the recipient already owns cannot be gifted again")
	assert(string.find(purchases, "for _, passId in ipairs(GiftedPasses.List(player)) do", 1, true),
		"Saved gifts switch their perks on at every join")
	local vip = read("src/common/ServerScriptService/Economy/VipSystem.server.luau")
	assert(string.find(vip, "(ok and owns) or GiftedPasses.Has(player, VIP_PASS_ID)", 1, true),
		"The VIP join check must not take away a gifted VIP")
	local shop = read("src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")
	assert(string.find(shop, "GiftContextRequest:FireServer(plr.UserId,giftProductId,id)", 1, true),
		"The shop asks for the pass's gift product")
	local config = read("src/common/ReplicatedStorage/Shared/Config.luau")
	for _, passId in { "1941409601", "1941060529", "1903494497", "1941301459", "1978623069", "1941169289" } do
		assert(string.find(config, "{ PassId = " .. passId, 1, true), "Pass " .. passId .. " needs a gift product entry")
	end
	print("PASS wiring: registered gift receipts, owned check, join-time perks, VIP and shop")
end

-- 2026-09-18: the pass treadmills (Needoh, Admin, Hacker) take a gifted pass too, and the
-- admin panel's Treadmills tool gives one to a player.
do
	local training = read("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau")
	local a = assert(string.find(training, "local function getPlayerGamePassTables", 1, true))
	local b = assert(string.find(training, "local function getPlayerRebirths", a, true))
	local gifted = {}
	local robux = {}
	local player = { UserId = 1, Name = "Runner" }
	local gamePassOwnershipCache, gamePassLastCheckedAt = {}, {}
	local playerOwnsGamePass = luau.load(string.sub(training, a, b - 1) .. "\nreturn playerOwnsGamePass", {
		environment = setmetatable({
			gamePassOwnershipCache = gamePassOwnershipCache,
			gamePassLastCheckedAt = gamePassLastCheckedAt,
			GAMEPASS_FALSE_CACHE_SECONDS = 2.5,
			MarketplaceService = { UserOwnsGamePassAsync = function(_, _, passId)
				return robux[passId] == true
			end },
			GiftedPasses = { Has = function(_, passId)
				return gifted[passId] == true
			end },
		}, { __index = _G }),
	})()
	assert(playerOwnsGamePass(player, 1954325260) == false, "No pass: the Hacker treadmill stays locked")
	gifted[1954325260] = true
	gamePassOwnershipCache[player] = nil
	assert(playerOwnsGamePass(player, 1954325260) == true, "A gifted Hacker pass lets them on")
	robux[1941090466] = true
	assert(playerOwnsGamePass(player, 1941090466) == true, "A bought pass still does")
	assert(string.find(training, "_G.SpeedsterForgetTreadmillPasses = function(player)", 1, true), "The treadmills forget their cached answer when told")

	local service = read("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	local c = assert(string.find(service, "local function treadmillPasses()", 1, true))
	local d = assert(string.find(service, "local UNLOCK_SHOWCASE", c, true))
	local commits, forgotten = {}, {}
	local config = { World2TreadmillProfiles = {
		Needoh = { GamePassId = 1941090466 }, Admin = { GamePassId = 1941342451 }, Hacker = { GamePassId = 1954325260 },
	} }
	local globals = { SpeedsterForgetTreadmillPasses = function(who)
		table.insert(forgotten, who)
	end }
	local treadmillPasses, setTreadmill = luau.load(string.sub(service, c, d - 1) .. "\nreturn treadmillPasses, setTreadmill", {
		environment = setmetatable({
			Config = config,
			_G = globals,
			commit = function(_, commands)
				table.insert(commits, commands)
				return true
			end,
		}, { __index = _G }),
	})()
	local passes = treadmillPasses()
	assert(passes.Needoh == 1941090466 and passes.Admin == 1941342451 and passes.Hacker == 1954325260, "Needoh, Admin and Hacker, by their passes")
	assert(setTreadmill(player, "Hacker", true), "Give the Hacker treadmill")
	assert(#commits[1] == 1 and commits[1][1].kind == "GrantUpgrade" and commits[1][1].upgradeId == "GiftedPass:1954325260", "...saved as a gifted pass on the profile")
	assert(forgotten[1] == player, "...and the treadmills let them on at once")
	assert(setTreadmill(player, "All", false), "Take all of them away")
	assert(#commits[2] == 3 and commits[2][1].kind == "RemoveUpgrade", "...every saved treadmill gift removed")
	assert(not setTreadmill(player, "Basic", true), "Only the pass treadmills")
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	assert(string.find(controller, 'send({ action = "GrantTreadmill", treadmill = treadmill(), enabled = true })', 1, true), "The panel's Treadmills section gives them")
	assert(string.find(service, 'elseif action == "GrantTreadmill" then', 1, true), "...and the server handles it for the target")
	print("PASS treadmills: a gifted pass unlocks its treadmill; the admin panel gives or takes Needoh, Admin and Hacker")
end

print("ALL GAMEPASS GIFT CHECKS PASSED")
