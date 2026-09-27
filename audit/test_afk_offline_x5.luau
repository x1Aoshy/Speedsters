-- test_afk_offline_x5.luau
-- Earnings while away and Get x5 (Sung's review, 2026-09-18), running the real
-- Social/AfkRewardsService on a mocked data layer:
--   1. Back after 10+ minutes, the time away (capped at 8 hours) pays a share of the
--      player's own Speed (never less than the old 50 + 10 per level), and the Earnings
--      panel says "While you were away you earned +X Speed!". Under 10 minutes, nothing.
--   2. Get x5 without VIP is the ClaimX5 developer product at 19 R$ (not the 100 R$ VIP
--      pass): the server opens its prompt, and its receipt pays the offline rewards x5
--      once, else the zone's unclaimed rewards x5, else a guaranteed amount; a receipt
--      that does not land puts the zone's rewards back.
--   3. The receipt path, the panel's button and the config.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	return s
end
local function marker(name)
	return { __module = name }
end

-- The real Config (a plain workspace is enough to read World 1's settings).
local configEnv = setmetatable({
	Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2,
	CFrame = roblox.CFrame, NumberRange = roblox.NumberRange,
	workspace = { FindFirstChild = function() return nil end, GetAttribute = function() return nil end },
	game = { PlaceId = 0, GetService = function()
		return { FindFirstChild = function() return nil end, GetAttribute = function() return nil end }
	end },
}, { __index = _G })
local Config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = configEnv })()
local settings = Config.AfkZone
assert(settings.ClaimX5 and settings.ClaimX5.ProductId == 3713742489 and settings.ClaimX5.PriceRobux == 19,
	"Get x5 uses the configured 19 R$ developer product")
assert(settings.OfflineMinMinutes == 10 and settings.OfflineMaxMinutes >= 360 and settings.OfflineMaxMinutes <= 480, "Offline: from 10 minutes, capped at 6-8 hours")
assert(settings.OfflineSpeedShare > 0 and settings.OfflineSpeedShare < settings.SpeedShare, "Away pays less a minute than standing in the zone")
-- Use the configured product to catch an incorrect id before publishing the places.

local Data = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/DailyRewardsData.luau"), { environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }) })()
local DailyRewards = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/DailyRewards.luau"), { environment = setmetatable({
	game = { GetService = function()
		return { WaitForChild = function(self) return self end }
	end },
	require = function() return Data end,
}, { __index = _G }) })()

-- The data layer: one profile per player, commits recorded (and applied to the profile).
local profiles, commits, rejectClaimAfk = {}, {}, false
local DataService = {}
function DataService.GetHandle(userId)
	return profiles[userId] and { UserId = userId } or nil
end
function DataService.Inspect(handle)
	return { ok = true, value = { profile = profiles[handle.UserId] } }
end
function DataService.Commit(handle, request)
	table.insert(commits, { UserId = handle.UserId, Request = request })
	for _, command in request.commands do
		if command.kind == "ClaimAfk" then
			local profile = profiles[handle.UserId]
			if rejectClaimAfk or (profile.LastAfkClaimTimestamp or 0) >= command.sessionStart then
				return { kind = "Rejected" }
			end
			profile.LastAfkClaimTimestamp = command.sessionStart
		end
	end
	return { kind = "Committed" }
end

local updates, prompts = {}, {}
local requestRemote = { OnServerEvent = signal() }
local updateRemote = { FireClient = function(_, player, payload)
	table.insert(updates, { Player = player, Payload = payload })
end }
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), list = {} }
function players:GetPlayers()
	return self.list
end
local modules = {
	FeatureGate = { IsPreviewPlayer = function() return true end },
	Config = Config,
	DailyRewards = DailyRewards,
	DataService = DataService,
	ServerRateLimiter = { Allow = function() return true end },
}
local shared = { WaitForChild = function(_, name) return marker(name) end }
local remotes = { FindFirstChild = function(_, name)
	return if name == "AfkRewardsRequest" then requestRemote elseif name == "AfkRewardsUpdate" then updateRemote else nil
end }
local globals = {}
local env = setmetatable({
	_G = globals,
	game = { GetService = function(_, name)
		if name == "Players" then
			return players
		elseif name == "ReplicatedStorage" then
			return { WaitForChild = function(_, child)
				return if child == "Shared" then shared else remotes
			end }
		elseif name == "MarketplaceService" then
			return { PromptProductPurchase = function(_, player, productId)
				table.insert(prompts, { Player = player, ProductId = productId })
			end }
		elseif name == "ServerScriptService" then
			return { Services = { Data = { DataService = marker("DataService") }, ServerRateLimiter = marker("ServerRateLimiter") } }
		end
		error("service " .. name)
	end },
	require = function(target)
		return assert(modules[target.__module], tostring(target.__module))
	end,
	task = { defer = function(fn, ...) fn(...) end, spawn = function(fn, ...) fn(...) end },
	Instance = { new = function() error("no remote should be created") end },
	warn = function() end,
	math = setmetatable({ random = function() return 50 end }, { __index = math }),
}, { __index = _G })
luau.load(fs.readFile("src/common/ServerScriptService/Social/AfkRewardsService.server.luau"), { environment = env })()

local nextId = 100
local function join(awaySeconds, speed, level, vip)
	nextId += 1
	local attributes = { Level = level, VIPGamepassOwned = vip == true }
	local changed = {}
	local player = { UserId = nextId, Name = "P" .. nextId, Parent = players }
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:SetAttribute(key, value)
		attributes[key] = value
		if changed[key] then
			changed[key]:Fire()
		end
	end
	function player:GetAttributeChangedSignal(key)
		changed[key] = changed[key] or signal()
		return changed[key]
	end
	profiles[player.UserId] = { Speed = speed, LastLogoutTimestamp = if awaySeconds then os.time() - awaySeconds else 0, LastAfkClaimTimestamp = 0 }
	table.insert(players.list, player)
	players.PlayerAdded:Fire(player)
	player:SetAttribute("DataLoaded", true)
	return player
end
local function lastUpdate(player)
	for index = #updates, 1, -1 do
		if updates[index].Player == player then
			return updates[index].Payload
		end
	end
	return nil
end

-- 1. Earnings while away.
local speed = 3e16
local veteran = join(3 * 3600, speed, 200)
local offer = lastUpdate(veteran)
local perMinute = speed * settings.OfflineSpeedShare
assert(offer.eligible == true and offer.minutes == 180, "Three hours away count 180 minutes")
assert(offer.speed == math.floor(180 * perMinute), "Each minute away pays a share of the player's own Speed")
assert(offer.message == "While you were away you earned +1.62Qa Speed!", "The panel welcomes them back with what they earned: " .. offer.message)
local sleeper = join(30 * 3600, speed, 200)
assert(lastUpdate(sleeper).minutes == settings.OfflineMaxMinutes, "Earnings stop at the cap (8 hours)")
local newbie = join(2 * 3600, 5, 3)
assert(lastUpdate(newbie).speed == 120 * (50 + 3 * 10), "A new player still earns the floor (50 + 10 per level a minute)")
local quick = join(5 * 60, speed, 200)
assert(lastUpdate(quick).eligible == false and lastUpdate(quick).speed == 0, "Under 10 minutes away earns nothing")
local fresh = join(nil, speed, 200)
assert(lastUpdate(fresh).eligible == false, "A first visit has nothing to collect")
local crashed = join(3 * 3600, speed, 200)
-- (join() fires DataLoaded at once, so this player is rebuilt by hand)
do
	nextId += 1
	local attributes = { Level = 200 }
	local changed = {}
	local player = { UserId = nextId, Name = "P" .. nextId, Parent = players }
	function player:GetAttribute(key) return attributes[key] end
	function player:SetAttribute(key, value) attributes[key] = value; if changed[key] then changed[key]:Fire() end end
	function player:GetAttributeChangedSignal(key) changed[key] = changed[key] or signal(); return changed[key] end
	profiles[player.UserId] = { Speed = speed, LastLogoutTimestamp = os.time() - 5 * 3600, LastAfkClaimTimestamp = 0, LastSaveUnix = os.time() - 4 * 60 }
	table.insert(players.list, player)
	players.PlayerAdded:Fire(player)
	player:SetAttribute("DataLoaded", true)
	local status = lastUpdate(player)
	assert(status.eligible == false and status.minutes == 4, "A session that never logged out (crash) counts from its last save: played time is not time away")
	local before = #prompts
	requestRemote.OnServerEvent:Fire(player, { action = "BuyX5" })
	assert(#prompts == before, "With nothing to multiply the server opens no prompt")
end
print("PASS offline: 10+ minutes away pay a share of the player's Speed (floor by level), capped at 8 hours, with a welcome-back message")

-- 2. Get x5.
requestRemote.OnServerEvent:Fire(veteran, { action = "BuyX5" })
assert(prompts[#prompts].Player == veteran and prompts[#prompts].ProductId == 3713742489, "Get x5 opens the 19 R$ product's prompt")
local vip = join(3 * 3600, speed, 200, true)
local promptsBefore = #prompts
requestRemote.OnServerEvent:Fire(vip, { action = "Claim", mode = "VIP" })
assert(lastUpdate(vip).claimed ~= true and lastUpdate(vip).eligible == true, "There is no free x5 for VIP: a VIP claim is not a request any more")
requestRemote.OnServerEvent:Fire(vip, { action = "BuyX5" })
assert(#prompts == promptsBefore + 1 and prompts[#prompts].ProductId == 3713742489, "VIP owners buy the same 19 R$ product: Get x5 never looks at VIP")

local plan = globals.SpeedsterAfkClaimX5Plan(veteran)
assert(plan.Source == "Offline", "Bought while offline rewards wait: those, five times over")
local beforeClaim = #commits
requestRemote.OnServerEvent:Fire(veteran, { action = "Claim", mode = "Normal" })
assert(#commits == beforeClaim, "Normal Claim cannot consume offline rewards reserved by x5")
assert(globals.SpeedsterAfkClaimX5Plan(veteran) == nil, "Another receipt waits while the first commits")
local granted = {}
for _, command in plan.Commands do
	granted[command.kind .. (command.stat or "")] = command
end
assert(granted.ClaimAfk and granted.GrantExactSpeed.amount == offer.speed * 5, "The receipt pays the offline Speed x5 and marks the claim")
local ok = DataService.Commit({ UserId = veteran.UserId }, { operationId = "receipt:1", commands = plan.Commands })
assert(ok.kind == "Committed", "The receipt's transaction lands")
plan.Committed()
assert(lastUpdate(veteran).claimed == true and lastUpdate(veteran).speed == offer.speed * 5, "The panel shows the x5 collected")
requestRemote.OnServerEvent:Fire(veteran, { action = "Claim", mode = "Normal" })
assert(lastUpdate(veteran).claimed == false and lastUpdate(veteran).eligible == false, "The offline rewards cannot be collected again")

-- Then again with the zone's rewards waiting.
local restored = false
globals.SpeedsterAfkZoneTake = function(player)
	return { Speed = 1000, Tickets = 2, Count = 3, Restore = function()
		restored = true
	end }
end
local zonePlan = globals.SpeedsterAfkClaimX5Plan(veteran)
assert(zonePlan.Source == "Zone", "With the offline rewards collected, the zone's rewards")
local zoneSpeed, zoneTickets = nil, nil
for _, command in zonePlan.Commands do
	if command.kind == "GrantExact" then
		zoneSpeed = command.amount
	elseif command.kind == "GrantSpinTickets" then
		zoneTickets = command.amount
	end
end
assert(zoneSpeed == 5000 and zoneTickets == 2, "...their Speed x5, and the spin tickets they held")
zonePlan.Failed()
assert(restored, "A receipt that does not land puts the zone's rewards back")

-- And with nothing waiting at all: never an empty purchase.
globals.SpeedsterAfkZoneTake = function()
	return nil
end
local fallback = globals.SpeedsterAfkClaimX5Plan(veteran)
assert(fallback.Source == "Fallback" and fallback.Commands[1].amount == math.floor(50 * math.max(settings.SpeedFloor, speed * settings.SpeedShare)),
	"With nothing waiting, it pays five times ten minutes of the zone")
print("PASS Get x5: the 19 R$ product (the same product for all players), paid once: offline x5, else the zone's x5, else a guaranteed amount; a failed receipt restores the zone")

-- 3. The receipt, the panel and the leftovers.
local purchases = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
has(purchases, 'productsById[productId] = { Kind = "AfkClaimX5", Data = claimX5 }', "The receipt knows the Get x5 product")
has(purchases, "afkPlan=DataService and type(_G.SpeedsterAfkClaimX5Plan)==\"function\" and _G.SpeedsterAfkClaimX5Plan(grantPlayer) or nil", "...asks the AFK service what to pay")
has(purchases, "if not commitPersistentReceipt(player,grantPlayer,receiptInfo,productEntry,commands) then\n\t\t\tif afkPlan then pcall(afkPlan.Failed) end", "...and pays it in the receipt's own transaction")
local panel = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau")
has(panel, 'AfkRewardsRequest:FireServer({ action = "BuyX5" })', "The panel's Get x5 asks the server for the product")
has(panel, "fiveXPrice.Text = tostring(claimX5Price)", "...and its tag always shows the product's price")
for _, word in { "VIPGamepassOwned", "VipGamePassId", "VipPriceRobux", "PromptGamePassPurchase" } do
	assert(not string.find(panel, word, 1, true), "The Earnings panel never looks at VIP: " .. word)
end
local service = fs.readFile("src/common/ServerScriptService/Social/AfkRewardsService.server.luau")
assert(not string.find(service, "VIPGamepassOwned", 1, true), "...and neither does the service")
-- AFK Mode (2026-09-18) pays straight into the player's data: no zone rewards wait for a
-- Get x5 receipt any more (the receipt still takes them from a service that offers them).
local zone = fs.readFile("src/common/ServerScriptService/Social/AfkZoneService.server.luau")
has(zone, "_G.SpeedsterAfkZoneTake = function(player: Player)", "AFK Mode hands its unclaimed stint to the Get x5 receipt")
players.PlayerRemoving:Fire(veteran)
print("PASS the receipt pays Get x5 through the AFK service, and the panel sells the product at its price for all players")
