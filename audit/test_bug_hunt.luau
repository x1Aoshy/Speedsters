-- test_bug_hunt.luau
-- Regressions for the September 2026 bug hunt: effects that outlived their character or
-- their player, the Spin Wheel's one-spin-at-a-time lock, the shop's single charge per
-- purchase, and cosmetic multipliers that can never break a player's speed.
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

----------------------------------------------------------------------
-- 1. Two Spin requests at once: the second is dropped while the first is in flight
----------------------------------------------------------------------
do
	local service = fs.readFile("src/common/ServerScriptService/Economy/SpinWheelService.server.luau")
	local busy = {}
	local sent = {}
	local exclusive = luau.load(between(service, "local function exclusive(", "local function spin(") .. "\nreturn exclusive", {
		environment = setmetatable({
			busy = busy,
			send = function(player, extra)
				table.insert(sent, extra)
			end,
			warn = function() end,
		}, { __index = _G }),
	})()
	local player = { Name = "Runner" }
	local paid = 0
	-- The first spin is waiting on its save (the commit yields)...
	local first = coroutine.create(function()
		exclusive(player, function()
			paid += 1
			coroutine.yield()
		end)
	end)
	coroutine.resume(first)
	assert(busy[player] == true, "A spin in flight holds the player's lock")
	-- ...and a second packet arrives meanwhile, and another.
	exclusive(player, function()
		paid += 1
	end)
	exclusive(player, function()
		paid += 1
	end)
	assert(paid == 1, "Packets sent together spin once")
	coroutine.resume(first)
	assert(busy[player] == nil, "The lock is released when the spin is done")
	exclusive(player, function()
		paid += 1
	end)
	assert(paid == 2, "The next spin goes through")
	-- A spin that fails still releases the lock and tells the player.
	exclusive(player, function()
		error("save failed")
	end)
	assert(busy[player] == nil and #sent == 1, "A failed spin releases the lock and says so")
	has(service, "local commands, title = rewardFor(player, index, profile)\n\ttable.insert(commands, 1, spend)", "The spin is spent and paid in one commit")
	has(service, 'exclusive(player, function()\n\t\t\tspin(player)', "Every Spin request goes through the lock")
	has(service, 'exclusive(player, function()\n\t\t\tbuyWithWins(player)', "...and every Wins purchase")
	has(service, "busy[player] = nil\n\trestricted[player] = nil", "A player who leaves takes their lock with them")
	print("PASS spin lock: packets sent together spin once; the lock is released on success, failure and leaving")
end

----------------------------------------------------------------------
-- 2. The shops charge once per item, whatever arrives twice
----------------------------------------------------------------------
do
	for _, shop in { "Aura", "Trail" } do
		local code = fs.readFile("src/common/ServerScriptService/Economy/" .. shop .. "ShopSystem.server.luau")
		-- The same operation id for the same item: a second Buy is AlreadyCommitted, never a
		-- second debit, even when the owned folder has not caught up yet.
		has(code, 'operationId="buy:' .. shop .. ':"..', shop .. " purchases are one operation per item")
		has(code, 'receiptId="owned:' .. shop .. ':"..', "...remembered as a receipt")
		has(code, "RemoteGuard.Connect(" .. shop .. "ShopAction, 0.25", "...and the shop remote is rate limited")
	end
	local receipts = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	has(receipts, 'operationId="receipt:"..purchaseId,receiptId=purchaseId', "Robux receipts (spin packs too) are paid once per PurchaseId")
	print("PASS shops: one debit per item and one payout per Robux receipt")
end

----------------------------------------------------------------------
-- 3. Cosmetic multipliers are always finite and at least 1
----------------------------------------------------------------------
do
	local env = { Color3 = rb.Color3, table = table, ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring, math = math, string = string, type = type }
	local Catalog = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau"), { environment = env })()
	for _, kind in { "Aura", "Trail" } do
		for _, entry in Catalog.GetList(kind) do
			local value = Catalog.GetSpeedMultiplier(kind, entry.Id)
			assert(value == entry.SpeedMultiplier and value >= 1 and value < math.huge, entry.Id .. " has a real multiplier")
		end
	end
	assert(Catalog.GetSpeedMultiplier("Aura", "") == 1 and Catalog.GetSpeedMultiplier("Aura", "NoSuchAura") == 1 and Catalog.GetSpeedMultiplier("Hat", "Aura01") == 1, "Nothing equipped (or an unknown id) is x1")
	for _, bad in { 0 / 0, math.huge, -5, 0, "x" } do
		table.insert(Catalog.Auras, { Id = "Broken", SpeedMultiplier = bad })
		assert(Catalog.GetSpeedMultiplier("Aura", "Broken") == 1, "A broken multiplier (" .. tostring(bad) .. ") reads as x1, never 0, NaN or infinity")
		table.remove(Catalog.Auras)
	end
	local service = fs.readFile("src/common/ServerScriptService/Economy/Cosmetics/CosmeticService.luau")
	has(service, 'player:SetAttribute("AuraSpeedGainMultiplier", Catalog.GetSpeedMultiplier("Aura", auraId or ""))', "Equipping an aura sets a safe multiplier")
	has(service, 'player:SetAttribute("TrailSpeedGainMultiplier", Catalog.GetSpeedMultiplier("Trail", trailId or ""))', "...and a trail too")
	local reducers = fs.readFile("src/common/ServerScriptService/Services/Data/ProfileReducers.luau")
	local _, count = string.gsub(reducers, "Catalog%.GetSpeedMultiplier%(", "")
	assert(count == 4, "The saved profile takes the same safe multiplier (" .. count .. " places)")
	local stats = fs.readFile("src/common/ServerScriptService/Progression/PlayerStats.server.luau")
	has(stats, "if badNumber(total) then\n\t\treturn 1", "The total gain falls back to x1 if it ever overflows")
	has(stats, "if badNumber(selectedWalkSpeed) or selectedWalkSpeed < 0 then", "WalkSpeed never becomes NaN or negative")
	print("PASS multipliers: every cosmetic is finite and at least x1; broken or missing values read as x1")
end

----------------------------------------------------------------------
-- 4. Effects end with their character or their player
----------------------------------------------------------------------
do
	local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	local list = string.match(effects, "local CHARACTER_EFFECTS = (%b{})")
	assert(list, "The client knows which trolls act on the character")
	-- Every troll that grabs the character when it starts (not fresh each frame, like the
	-- fireworks' shake) is on that list.
	for name, body in string.gmatch(effects, "function EFFECTS%.(%w+)%(([^\n]*\n.-)\nend\n") do
		local before = string.match(body, "^(.-)run%(") or ""
		if string.find(before, "character()", 1, true) then
			assert(string.find(list, '"' .. name .. '"', 1, true), name .. " acts on the character, so it ends with it")
		end
	end
	has(effects, "player.CharacterRemoving:Connect(function()\n\tfor _, name in CHARACTER_EFFECTS do", "A reset or death ends them at once")

	local panel = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	has(panel, 'local previous = Workspace:FindFirstChild("AdminJail_" .. player.UserId)', "A second jail replaces the first, never stacks")
	has(panel, "left = character.AncestryChanged:Connect(function()\n\t\tif not character:IsDescendantOf(Workspace) then\n\t\t\trelease()", "The jail goes when its prisoner resets or leaves")
	has(panel, "if playing then\n\t\t\tplaying:Stop(0)", "The DJ's dance track stops when the booth goes")

	local decor = fs.readFile("src/common/ServerScriptService/Gameplay/StageDecor.server.luau")
	has(decor, 'local lastSkipPromptAt = setmetatable({}, { __mode = "k" })', "Players who left are not kept by the skip prompt cooldown")
	local special = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/AuraSpecialEffectsClient.client.luau")
	local _, weak = string.gsub(special, '__mode = "k"', "")
	assert(weak >= 2, "The aura floor and ball client forgets destroyed pieces")
	local skins = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
	has(skins, 'setmetatable({}, { __mode = "k" }) :: any', "The Tung Tung watchers never keep a character alive")
	print("PASS cleanup: trolls end with the character, the jail with its prisoner, and no table keeps a player or character that is gone")
end
