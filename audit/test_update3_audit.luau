--!strict
-- audit/test_update3_audit.luau
-- Guards the seven fixes from the Update 3 audit.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function read(path) return fs.readFile(path) end

-- 1. Evolve skin must not sit behind a blind delay on respawn.
local skins = read("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
assert(string.find(skins, "waitForCharacterReady", 1, true),
	"The skin must wait for the Humanoid and the appearance, not a fixed delay")
assert(string.find(skins, "player.CharacterAppearanceLoaded:Connect(function(character)", 1, true),
	"Readiness must come from CharacterAppearanceLoaded, which fires for every character")
assert(not string.find(skins, "task.wait(1)\n\t\t\tif player.Parent and player.Character == character", 1, true),
	"The one second respawn delay must be gone")

-- 1b. Respawn: Player:HasAppearanceLoaded() is per player and already true, but this
-- character's avatar is not in yet. Applying now read back an empty description
-- (black body colours, no face, no accessories). Run the real wait against that.
do
	local startAt = assert(string.find(skins, "local appearanceReady = setmetatable", 1, true))
	local stopAt = assert(string.find(skins, "local function setupPlayer(player)", startAt, true))
	local chunk = string.sub(skins, startAt, stopAt - 1)
		.. "\nreturn waitForCharacterReady, appearanceReady, APPEARANCE_WAIT_SECONDS"

	local now = 0
	local onTick = nil
	local env = {
		os = { clock = function() return now end },
		task = { wait = function() now += 1 / 60; if onTick then onTick() end end },
	}
	local waitForCharacterReady, appearanceReady, timeout = luau.load(chunk, { environment = env })()

	local function makePlayer()
		local character = { FindFirstChildOfClass = function() return {} end }
		local player = {
			Parent = "Players",
			Character = character,
			-- The trap: already true on a respawn.
			HasAppearanceLoaded = function() return true end,
		}
		return player, character
	end

	-- The avatar lands 0.3 s after the spawn: the suit must wait for it, not for the flag.
	local player, character = makePlayer()
	local loadedAt = 0.3
	onTick = function()
		if now >= loadedAt then appearanceReady[character] = true end
	end
	now = 0
	assert(waitForCharacterReady(player, character) == true, "A loaded character must be ready")
	assert(now >= loadedAt and now < loadedAt + 0.05,
		string.format("The suit must go on right after this character's avatar loads, not at %.2f s", now))

	-- The player respawns again while waiting: the stale character is abandoned.
	local player2, character2 = makePlayer()
	onTick = function()
		if now >= 0.1 then player2.Character = { FindFirstChildOfClass = function() return {} end } end
	end
	now = 0
	assert(waitForCharacterReady(player2, character2) == false, "A replaced character must not get the suit")

	-- The avatar never loads: the suit still goes on once the wait runs out.
	local player3, character3 = makePlayer()
	onTick = nil
	now = 0
	assert(waitForCharacterReady(player3, character3) == true, "A stuck avatar load must not block the suit forever")
	assert(now >= timeout, "The fallback must wait the full timeout first")
	print("PASS respawn skin waits for this character's avatar, not the per-player flag")
end

-- 2. Blue Trail: no blocking Marketplace call while the menu is built.
local backpack = read("src/common/StarterGui/Backpack/BackpackScript.client.luau")
assert(string.find(backpack, "item.robuxPurchaseId = catalogId", 1, true),
	"The purchase id must be known from the catalog so a click works immediately")
assert(not string.find(backpack, "local _, price = resolveRobux(entry)", 1, true),
	"resolveRobux yields; it must not run while wiring each row")
assert(not string.find(backpack, "local purchaseType, _, purchaseId = resolveRobux(entry)", 1, true),
	"The click handler must not depend on a blocking lookup at wire time")

-- 3. The 2X Win card sells the permanent gamepass, not the map pad product.
local shop = read("src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")
assert(string.find(shop, '["2X Win"] = { type = "GamePass", id = twoXVictoryPassId }', 1, true),
	"The 2X Win card must point at the permanent gamepass")
assert(not string.find(shop, "Config.DoubleWinsPadProductId", 1, true),
	"The shop must not read the map pad product id; that is what mis-sold this card")
assert(string.find(shop, 'player:GetAttribute("TwoXVictoryOwned") == true', 1, true),
	"Ownership must read the gamepass flag so the card can show Purchased")

-- 5. The unfinished systems stay off live servers. Quests, AFK and the shatter are
-- preview features (Studio, testing places, preview accounts); the old admin panel is
-- still Studio only.
local PREVIEW_ONLY = {
	"src/common/StarterPlayer/StarterPlayerScripts/UI/QuestController.client.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau",
	"src/common/ReplicatedStorage/Shared/GlassShatter.luau",
}
for _, path in ipairs(PREVIEW_ONLY) do
	local source = read(path)
	assert(string.find(source, "IsPreviewPlayer", 1, true), path .. " must be gated by Shared.FeatureGate")
	assert(not string.find(source, "if true then", 1, true), path .. " must not be hard-disabled")
end
local adminPanel = read("src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau")
assert(string.match((string.gsub(adminPanel, "%-%-[^\n]*", "")), "^%s*$"), "The old AdminPanelController is retired and must hold no code")
local gate = read("src/common/ReplicatedStorage/Shared/FeatureGate.luau")
assert(string.find(gate, "RunService:IsStudio()", 1, true), "The preview gate always opens in Studio")
local topbar = read("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
assert(string.find(topbar, 'panel = "AdminAbusePanelGui"', 1, true) and not string.find(topbar, 'panel = "SpeedsterAdminPanelGui"', 1, true),
	"The one admin topbar icon must follow the panel it opens")

-- 6. Offset-built panels must use the scaling mode, not the clipping one. The AFK panel
-- is the designer's scale-based layout now, so it keeps the designer's sizes instead.
assert(string.find(read("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau"),
	'require(Shared:WaitForChild("DesignerUi"):WaitForChild("EarningsGui"))', 1, true),
	"The AFK panel must be the designer's Earnings layout")
-- The Quests panel is the designer's Choose Your Destiny layout (design/ui/Quests.rbxm):
-- the saved StarterGui panel, or the generated module where a place has none, finished
-- by Shared.QuestUi; its one UIScale pops it open and closed, and phones scroll its cards.
do
	local path = "src/common/StarterPlayer/StarterPlayerScripts/UI/QuestController.client.luau"
	local source = read(path)
	assert(string.find(source, 'require(Shared:WaitForChild("DesignerUi"):WaitForChild("QuestGui"))', 1, true), path .. " must use the designer's quest layout")
	assert(string.find(source, "QuestUi.Decorate(gui)", 1, true) and string.find(source, "QuestUi.Layout(", 1, true), path .. " must finish and lay out the designer's panel")
	assert(not string.find(source, "PanelStyle.BlockyWindow(", 1, true) and not string.find(source, "PanelStyle.Panel(", 1, true), path .. " must not build a code window any more")
	assert(string.find(source, "TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)", 1, true)
		and string.find(source, "TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)", 1, true),
		path .. " must pop open (Back.Out 0.35 s) and shrink closed (Quad.In 0.2 s)")
	assert(string.find(source, "panelScale.Scale = layout.Scale * 0.85", 1, true) and string.find(source, "* 0.8 })", 1, true),
		path .. " must open from 0.85 and close to 0.8 of the panel's scale")
	assert(string.find(source, 'QuestRequest:FireServer({ action = "Choose", choice = index })', 1, true), path .. " must pick with choice")
	assert(string.find(source, 'QuestRequest:FireServer({ action = "State" })', 1, true), path .. " must ask for the new day's state")
end
local blocky = read("src/common/ReplicatedStorage/Shared/GamePanelStyle.luau")
assert(string.find(blocky, "fit.Scale=math.min(1,", 1, true), "The blocky window shrinks to the viewport and never grows")
local style = read("src/common/ReplicatedStorage/Shared/GamePanelStyle.luau")
assert(string.find(style, "scale.Scale=math.min(1", 1, true),
	"GamePanelStyle must still scale non-adaptive panels to the viewport")

-- 7. Time Gifts: the claim cannot latch the player out.
local playtime = read("src/common/ServerScriptService/Social/PlaytimeRewards.server.luau")
assert(string.find(playtime, "pcall(DataService.Commit", 1, true),
	"A throwing commit must not leave session.Busy latched forever")
assert(string.find(playtime, "operationId=id,receiptId=id", 1, true),
	"Claims must stay idempotent through the receipt id")
assert(string.find(playtime, "Workspace:GetServerTimeNow()", 1, true),
	"The timer must run on the server clock")
assert(not string.find(playtime, "local function rollback", 1, true),
	"The dead pre-DataService grant path should be gone")

-- 4. The ladder, checked against the real dashboard prices.
local stub = {}
stub.GetAttribute = function() return nil end
stub.FindFirstChild = function() return nil end
stub.WaitForChild = function() return stub end
local Config = luau.load(read("src/common/ReplicatedStorage/Shared/Config.luau"), {
	environment = {
		game = { GetService = function() return stub end, PlaceId = 85065221510105 },
		workspace = stub, Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, UDim2 = roblox.UDim2, table = table, math = math, string = string, os = os,
		ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring, type = type,
		typeof = typeof, next = next, select = select, pcall = pcall, error = error, assert = assert,
		print = function() end, warn = function() end,
	},
})()
local ladder = Config.PermanentWinsMultiplierProducts
assert(#ladder == 5, "The ladder should run x2 through x32")
assert(tonumber(Config.TwoXVictoryGamePassId) == 1941409601, "2X Victory (x2 pads) gamepass id changed")
assert(tonumber(Config.RetiredDoubleWinsPadProductId) == 3712435111, "The retired x2 Wins (PAD) product id changed")
local expected = { [1] = 3710772221, [2] = 3710772271, [3] = 3710772305, [4] = 3710772331, [5] = 3710772380 }
for index, id in pairs(expected) do
	assert(tonumber(ladder[index].ProductId) == id,
		"Ladder rung " .. index .. " must keep the dashboard product whose name matches its multiplier")
end

print("PASS Update 3 audit: skins, Blue Trail, 2X Win card, wins ladder, Studio gating, panel scaling, Time Gifts")
