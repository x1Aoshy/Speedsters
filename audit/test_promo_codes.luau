--!strict
-- audit/test_promo_codes.luau
-- Only BOOST redeems, the redeem panel stays parked, and the Update Logs banner
-- is generated from the catalog so it cannot advertise a retired code.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function load(path, extraEnv)
	local env = {
		table = table, math = math, string = string, os = os,
		ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring,
		type = type, typeof = typeof, next = next, select = select, pcall = pcall,
		error = error, assert = assert, print = function() end, warn = function() end,
		Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, UDim2 = roblox.UDim2,
	}
	for k, v in pairs(extraEnv or {}) do env[k] = v end
	return luau.load(fs.readFile(path), { environment = env })()
end

local stub = {}
stub.GetAttribute = function() return nil end
stub.FindFirstChild = function() return nil end
stub.WaitForChild = function() return stub end
local Config = load("src/common/ReplicatedStorage/Shared/Config.luau", {
	game = { GetService = function() return stub end, PlaceId = 85065221510105 },
	workspace = stub,
})
local Catalog = load("src/common/ReplicatedStorage/Shared/Catalogs/CodesCatalog.luau")

-- 1. BOOST is the only code that redeems.
assert(Catalog.Get("BOOST") ~= nil, "BOOST must redeem")
assert(Catalog.Get("boost") ~= nil, "BOOST must be case-insensitive")
assert(Catalog.Get(" Boost ") ~= nil, "BOOST must tolerate stray whitespace")

local RETIRED = {
	"sorry4bugs", "thanks4playing", "update2", "7kccu", "5mvisits", "250kgroupmembers",
	"sorry4delayedupdate", "sorry4delayedupdate2day", "gifting", "gift", "admingiveaway",
	"admingiv3away", "wins", "gekkoh", "geko", "gekofly", "fly20", "hitbox", "lag", "nolag",
	"thankyousomuchfor20kvisits", "reach87percentlike",
}
for _, code in ipairs(RETIRED) do
	assert(Catalog.Get(code) == nil, "Retired code still redeems: " .. code)
end

-- No stragglers: count every definition in the table.
local live = {}
for key, value in pairs(Catalog) do
	if type(value) == "table" and value.Marker ~= nil then
		table.insert(live, key)
	end
end
-- 2026-09-26 (owner): plus the three Update 4 codes.
assert(#live == 7, "Expected BOOST, three Update 3 codes and three Update 4 codes")
for _, name in { "UPDATE3", "NEWWORLD", "ADMINPARTY", "UPDATE4ISHERE", "RACES", "EGGMAN" } do
	assert(Catalog.Get(name) ~= nil, "New code missing: " .. name)
	assert(Catalog.Get(string.lower(name)) == Catalog.Get(name), "Codes are case-insensitive: " .. name)
end
local markers = {}
for _, key in ipairs(live) do
	local marker = Catalog[key].Marker
	assert(not markers[marker], "Two codes share the one-time marker " .. marker)
	markers[marker] = true
end

-- 2. The announced list matches what actually redeems.
local active = Catalog.Active or {}
assert(#active == 3 and active[1] == "UPDATE4ISHERE", "CodesCatalog.Active lists the three Update 4 codes")
for _, shown in ipairs(active) do
	assert(Catalog.Get(shown) ~= nil, "Update Logs advertises a code that does not redeem: " .. shown)
end

-- 3. The duplicate card-list modal stays parked and cannot pop up on its own.
assert(Config.PromoCodesModalEnabled == false, "The duplicate codes card list must stay parked")
local modal = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/CodesModalController.client.luau")
assert(string.find(modal, "Config.PromoCodesModalEnabled ~= true", 1, true),
	"CodesModalController must bail out while it is parked")
local logs = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau")
assert(not string.find(logs, "OpenCodesModal", 1, true),
	"Closing the Update Logs must not reach the parked panel at all")
assert(string.find(logs, "CodesCatalog.Active", 1, true),
	"The Update Logs banner must come from the catalog, not hardcoded text")

-- 4. Codes are redeemed in the Shop's own codes section (Update 4, 2026-09-25: the topbar Codes
-- icon was removed as redundant; audit/test_u4_ui_cleanup covers the topbar).
local topbar = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
assert(not string.find(topbar, 'request = "Codes"', 1, true), "Codes open from the Shop, not the topbar")

local shop = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")
assert(string.find(shop, 'MenuEvents.Get("OpenCodesPanel")', 1, true),
	"The Shop must answer the Codes request; that event used to have no listener")
assert(string.find(shop, 'smoothScrollToCategory("Codes")', 1, true),
	"Opening Codes must land on the Codes section, not the top of the shop")
assert(string.find(shop, "CaptureFocus", 1, true),
	"Opening Codes should focus the redeem box so the player can type straight away")
assert(string.find(shop, "wireCodesSection", 1, true), "The Shop still owns the redeem box")

print("PASS codes: BOOST, three Update 3 and three Update 4 codes, banner from catalog, redeem in the Shop")
