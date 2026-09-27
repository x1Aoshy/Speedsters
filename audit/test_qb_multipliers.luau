-- audit/test_qb_multipliers.luau  (2026-09-21)
-- The permanent Speed / Wins multipliers (the x2..x32 ladders and the OG x2/x4/x10 products)
-- must survive everything that is not a purchase, and they must pay in World 3 too. With the
-- REAL modules and sources:
--   a. ProfileCodec keeps an OG-shaped save's x4 Wins / x30 Speed through Decode and Encode;
--   b. ProfileReducers: a monotonic SetPersistent keeps 8 when asked for 2 (a plain one lowers);
--   c. the admin pass toggles of BOTH admin services (AdminPanelService, AdminAbusePanelService),
--      TwoXSpeed and "All", give and remove, leave a paid x16 at 16 and raise a x1 to 2; a
--      gifted Flight is not taken away by "remove All";
--   d. GiftedPasses.Commands(2x Speed) through the real reducers raises 1 -> 2 and keeps 8;
--   e. PlayerStatsBridge's two multiplier setters never lower (attribute or profile command);
--   f. MainHUDController no longer writes either multiplier attribute on the client;
--   g. RewardPadClaims with a x4 multiplier pays World 3 Stage 2's 750,000 pad 3,000,000 (and
--      the finish 40,000,000): the OG multipliers work in World 3.
--   lune run audit/test_qb_multipliers.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")

local C = "src/common/"
local CONFIG = C .. "ReplicatedStorage/Shared/Config.luau"
local ADMIN_PANEL = C .. "ServerScriptService/Admin/AdminPanelService.server.luau"
local ADMIN_ABUSE = C .. "ServerScriptService/Admin/AdminAbusePanelService.server.luau"
local BRIDGE = C .. "ServerScriptService/Progression/PlayerStatsBridge.luau"
local GIFTS = C .. "ServerScriptService/Services/Monetization/GiftedPasses.luau"
local PURCHASES = C .. "ServerScriptService/Economy/SpeedProductPurchases.server.luau"
local HUD = C .. "StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau"
local CLAIMS = C .. "ServerScriptService/Services/RewardPadClaims.luau"
local W3_PADS = "src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau"

local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

-- Every changed source compiles.
for _, path in { ADMIN_PANEL, ADMIN_ABUSE, BRIDGE, GIFTS, PURCHASES, HUD, CLAIMS } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. ": " .. tostring(problem))
end
pass("the seven sources compile")

local BASE_ENV = {
	table = table, math = math, string = string, os = os, ipairs = ipairs, pairs = pairs, tonumber = tonumber,
	tostring = tostring, type = type, typeof = typeof, next = next, select = select, pcall = pcall, error = error,
	assert = assert, setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget,
	print = function() end, warn = function() end,
}
local function env(extra)
	local e = table.clone(BASE_ENV)
	for k, v in extra do
		e[k] = v
	end
	return e
end

-- The real World 3 Config (World 3 knows itself by its place id).
local Config
do
	local stub = {}
	stub.GetAttribute = function() return nil end
	stub.FindFirstChild = function() return nil end
	stub.WaitForChild = function() return stub end
	Config = luau.load(fs.readFile(CONFIG), { environment = env({
		game = { GetService = function() return stub end, PlaceId = 128432111599629 }, workspace = stub,
		Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame, Enum = rb.Enum, UDim2 = rb.UDim2,
	}) })()
	assert(Config.IsWorld3Place == true, "Config did not load as World 3")
	assert(tonumber(Config.TwoXSpeedGamePassId) and Config.TwoXSpeedGamePassId > 0, "no 2x Speed pass id")
end

local function profileWith(fields)
	local decoded = Codec.Decode({ Version = 306, Speed = 1, Wins = 0 })
	assert(decoded.ok, "a fresh profile decodes")
	local profile = decoded.value
	for k, v in fields do
		profile[k] = v
	end
	return profile
end

-- Applies commands with the real reducer; multiplier commands must succeed.
local function applyAll(profile, commands)
	for _, command in commands do
		local ok, result = pcall(Reducers.ApplyCommand, profile, command, 1790000000)
		if command.kind == "SetPersistent" or command.kind == "PurchaseMultiplier" then
			assert(ok and result and result.ok, "reducer refused " .. command.kind .. " " .. tostring(command.key) .. ": " .. tostring(result))
		end
	end
	return profile
end

----------------------------------------------------------------------
-- a. The OG save keeps its multipliers through the codec
----------------------------------------------------------------------
do
	local raw = { Version = 306, Speed = 12345, Wins = 678, PermanentWinsMultiplier = 4, PermanentBaseSpeedMultiplier = 30 }
	local decoded = Codec.Decode(raw)
	assert(decoded.ok, "the OG-shaped save decodes")
	assert(decoded.value.PermanentWinsMultiplier == 4, "Decode kept Wins x" .. tostring(decoded.value.PermanentWinsMultiplier))
	assert(decoded.value.PermanentBaseSpeedMultiplier == 30, "Decode kept Speed x" .. tostring(decoded.value.PermanentBaseSpeedMultiplier))
	local encoded = Codec.Encode(decoded.value)
	assert(encoded.PermanentWinsMultiplier == 4 and encoded.PermanentBaseSpeedMultiplier == 30, "Encode writes x4 / x30 back unchanged")
	local again = Codec.Decode(encoded)
	assert(again.ok and again.value.PermanentWinsMultiplier == 4 and again.value.PermanentBaseSpeedMultiplier == 30, "a second load keeps them")
	pass("ProfileCodec keeps an OG save's Wins x4 and Speed x30 (no clamp, no ladder snap) across Decode/Encode/Decode")
end

----------------------------------------------------------------------
-- b. SetPersistent monotonic
----------------------------------------------------------------------
do
	local p = profileWith({ PermanentBaseSpeedMultiplier = 8 })
	applyAll(p, { { kind = "SetPersistent", key = "PermanentBaseSpeedMultiplier", value = 2, monotonic = true } })
	assert(p.PermanentBaseSpeedMultiplier == 8, "monotonic SetPersistent lowered 8 to " .. tostring(p.PermanentBaseSpeedMultiplier))
	local plain = profileWith({ PermanentBaseSpeedMultiplier = 8 })
	applyAll(plain, { { kind = "SetPersistent", key = "PermanentBaseSpeedMultiplier", value = 2 } })
	assert(plain.PermanentBaseSpeedMultiplier == 2, "the plain SetPersistent is the lowering path (sanity)")
	pass("ProfileReducers: SetPersistent monotonic keeps x8 when asked for x2 (the plain one would lower it)")
end

----------------------------------------------------------------------
-- c. The admin pass toggles, both services
----------------------------------------------------------------------
do
	local giftedFlight = {}
	local GiftedStub = {
		Has = function(player, passId)
			return giftedFlight[player] == true and passId == Config.AbilityFlightGamePassId
		end,
	}
	-- AdminAbusePanelService reads the victim's saved profile (DataService) and, only when a Remove
	-- would lower it, whether they really own 2x Speed (MarketplaceService, GiftedPasses).
	local profiles, owners = {}, {}
	local ownershipAsked, marketFails = 0, false
	local DataStub = {
		GetHandle = function(userId)
			return if profiles[userId] then { userId = userId } else nil
		end,
		Inspect = function(handle)
			return { ok = true, value = { profile = profiles[handle.userId] } }
		end,
	}
	local Market = {
		UserOwnsGamePassAsync = function(_, userId, passId)
			ownershipAsked += 1
			if marketFails then
				error("HTTP 500")
			end
			return owners[userId] == true and passId == Config.TwoXSpeedGamePassId
		end,
	}
	local nextUserId = 0
	local function victimWith(profile)
		nextUserId += 1
		local victim = { UserId = nextUserId }
		function victim:GetAttribute(name)
			return profile[name]
		end
		profiles[nextUserId] = profile
		return victim
	end
	local builders = {
		{
			name = "AdminPanelService",
			fn = luau.load(between(read(ADMIN_PANEL), "local function buildPassToggleCommands", "\n-- Apply pass state", "AdminPanelService builder")
				.. "\nreturn buildPassToggleCommands", { environment = env({ GiftedPasses = GiftedStub, Config = Config }) })(),
		},
		{
			name = "AdminAbusePanelService",
			fn = luau.load(between(read(ADMIN_ABUSE), "-- 2026-09-21: a Give 2x Speed that actually raised", "\nlocal function setPass", "AdminAbusePanelService builder")
				.. "\nreturn passCommands", { environment = env({
				GiftedPasses = GiftedStub, Config = Config, DataService = DataStub,
				game = { GetService = function(_, name)
					assert(name == "MarketplaceService", "asked for " .. tostring(name))
					return Market
				end },
			}) })(),
			reads = true,
		},
	}
	for _, builder in builders do
		for _, passId in { "TwoXSpeed", "All" } do
			for _, enabled in { true, false } do
				local label = ("%s %s %s"):format(builder.name, enabled and "give" or "remove", passId)
				local paid = profileWith({ PermanentBaseSpeedMultiplier = 16 })
				local commands = builder.fn(if builder.reads then victimWith(paid) else {}, passId, enabled)
				applyAll(paid, commands)
				assert(paid.PermanentBaseSpeedMultiplier == 16, label .. ": a paid x16 became x" .. tostring(paid.PermanentBaseSpeedMultiplier))
				local fresh = profileWith({ PermanentBaseSpeedMultiplier = 1 })
				applyAll(fresh, builder.fn(if builder.reads then victimWith(fresh) else {}, passId, enabled))
				local expected = if enabled then 2 else 1
				assert(fresh.PermanentBaseSpeedMultiplier == expected, label .. ": x1 became x" .. tostring(fresh.PermanentBaseSpeedMultiplier))
				for _, command in commands do
					assert(command.key ~= "PermanentWinsMultiplier", label .. ": touches the Wins ladder")
					if command.key == "PermanentBaseSpeedMultiplier" then
						assert(enabled and command.monotonic == true, label .. ": a non-monotonic or removing Speed write")
					end
				end
			end
		end
		if builder.reads then
			-- Give then Remove takes back exactly the admin's raise, and nothing a player paid for.
			local function giveThenRemove(start, between, owner)
				local profile = profileWith({ PermanentBaseSpeedMultiplier = start })
				local victim = victimWith(profile)
				owners[victim.UserId] = owner == true
				applyAll(profile, builder.fn(victim, "TwoXSpeed", true))
				local marked = table.find(profile.OwnedUpgrades, "AdminTwoXSpeedRaise") ~= nil
				if between then
					between(profile)
				end
				applyAll(profile, builder.fn(victim, "All", false))
				assert(table.find(profile.OwnedUpgrades, "AdminTwoXSpeedRaise") == nil, "the mark is always cleared by a Remove")
				return profile.PermanentBaseSpeedMultiplier, marked
			end
			local value, marked = giveThenRemove(1)
			assert(marked and value == 1, "an admin x2 on a x1 player is taken back by Remove (got x" .. tostring(value) .. ")")
			value, marked = giveThenRemove(4)
			assert(not marked and value == 4, "a paid x4 is not marked and stays x4")
			value = giveThenRemove(1, function(profile)
				profile.PermanentBaseSpeedMultiplier = 4 -- bought the x4 rung meanwhile
			end)
			assert(value == 4, "a rung bought after the admin raise stays")
			value = giveThenRemove(1, nil, true)
			assert(value == 2, "a real 2x Speed pass owner keeps x2")
			marketFails = true
			value = giveThenRemove(1)
			marketFails = false
			assert(value == 2, "an ownership check that fails never lowers")
			local asked = ownershipAsked
			giveThenRemove(4)
			assert(ownershipAsked == asked, "ownership is asked only when a Remove would lower")
		end
		-- A gifted Flight: "remove All" keeps it; a player without the gift still loses the admin grant.
		local gifted = if builder.reads then victimWith(profileWith({})) else {}
		local plain = if builder.reads then victimWith(profileWith({})) else {}
		giftedFlight[gifted] = true
		local function touchesFlight(commands)
			for _, command in commands do
				if command.upgradeId == "Flight" or command.kind == "SetAbilityEquipped" then
					return true
				end
			end
			return false
		end
		assert(not touchesFlight(builder.fn(gifted, "All", false)), builder.name .. ": remove All took a gifted Flight")
		assert(not touchesFlight(builder.fn(gifted, "Flight", false)), builder.name .. ": remove Flight took a gifted Flight")
		assert(touchesFlight(builder.fn(plain, "All", false)), builder.name .. ": remove All no longer removes an admin Flight")
		assert(touchesFlight(builder.fn(gifted, "All", true)), builder.name .. ": give All no longer grants Flight")
	end
	pass("both admin toggles (TwoXSpeed and All, give and remove): a paid x16 stays x16, x1 -> x2 on give; Give then Remove takes back only the admin's own raise (marked), never a paid rung, a real pass owner or on a failed ownership check; a gifted Flight survives remove")
end

----------------------------------------------------------------------
-- d. A gifted 2x Speed saves its multiplier, raise-only
----------------------------------------------------------------------
do
	local stub = {}
	stub.WaitForChild = function() return stub end
	local Gifted = luau.load(fs.readFile(GIFTS), { environment = env({
		game = { GetService = function() return stub end },
		require = function() return Config end,
	}) })()
	local commands = Gifted.Commands(Config.TwoXSpeedGamePassId)
	local found = false
	for _, command in commands do
		if command.kind == "PurchaseMultiplier" and command.key == "PermanentBaseSpeedMultiplier" and command.target == 2 then
			found = true
		end
	end
	assert(found, "GiftedPasses.Commands(2x Speed) has no PurchaseMultiplier to 2")
	local low = applyAll(profileWith({ PermanentBaseSpeedMultiplier = 1 }), commands)
	assert(low.PermanentBaseSpeedMultiplier == 2, "gift raised x1 to x" .. tostring(low.PermanentBaseSpeedMultiplier))
	assert(table.find(low.OwnedUpgrades, Gifted.UpgradeId(Config.TwoXSpeedGamePassId)), "gift is recorded")
	local high = applyAll(profileWith({ PermanentBaseSpeedMultiplier = 8 }), Gifted.Commands(Config.TwoXSpeedGamePassId))
	assert(high.PermanentBaseSpeedMultiplier == 8, "gift lowered x8 to x" .. tostring(high.PermanentBaseSpeedMultiplier))
	-- Other gifts never touch the Speed ladder.
	local other = applyAll(profileWith({ PermanentBaseSpeedMultiplier = 1 }), Gifted.Commands(Config.VipGamePassId))
	assert(other.PermanentBaseSpeedMultiplier == 1, "a VIP gift moved the Speed ladder")
	-- The join refresh accepts the saved gift too (the repair for gifts made before this fix).
	local refresh = between(read(PURCHASES), "local function refreshTwoXSpeedPassOwnership", "local tenXPassId", "join refresh")
	assert(refresh:find("if (ok and ownsPass) or GiftedPasses.Has(player, passId) then", 1, true), "refreshTwoXSpeedPassOwnership ignores a gifted 2x Speed")
	pass("GiftedPasses.Commands(2x Speed) through the real reducers: x1 -> x2, x8 stays x8; the join refresh accepts the gift")
end

----------------------------------------------------------------------
-- e. The bridge setters never lower
----------------------------------------------------------------------
do
	local block = between(read(BRIDGE), "\tlocal function raiseMultiplier", "\t-- 7. SpeedsterSyncSuitSpeedGainMultiplier", "bridge setters")
	local commits = {}
	local DataStub = {
		GetHandle = function() return { userId = 1 } end,
		NewOperationId = function() return "op" end,
		Commit = function(_, request)
			table.insert(commits, request)
			return { kind = "Committed" }
		end,
	}
	local g = {}
	luau.load("local g = ...\n" .. block, { environment = env({ DataService = DataStub }) })(g)
	assert(type(g.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" and type(g.SpeedsterSetPermanentWinsMultiplier) == "function", "setters not defined")
	for _, case in {
		{ fn = g.SpeedsterSetPermanentBaseSpeedMultiplier, key = "PermanentBaseSpeedMultiplier" },
		{ fn = g.SpeedsterSetPermanentWinsMultiplier, key = "PermanentWinsMultiplier" },
	} do
		local attrs = { [case.key] = 8 }
		local player = {
			UserId = 1,
			GetAttribute = function(_, k) return attrs[k] end,
			SetAttribute = function(_, k, v) attrs[k] = v end,
		}
		table.clear(commits)
		case.fn(player, 2) -- a stale caller asks for less
		assert(attrs[case.key] == 8, case.key .. ": attribute lowered to " .. tostring(attrs[case.key]))
		assert(#commits == 1, case.key .. ": one commit")
		local profile = applyAll(profileWith({ [case.key] = 8 }), commits[1].commands)
		assert(profile[case.key] == 8, case.key .. ": profile lowered to " .. tostring(profile[case.key]))
		-- A real stale-attribute race: attribute 4 behind a profile already at 8.
		attrs[case.key] = 4
		table.clear(commits)
		case.fn(player, 4)
		local raced = applyAll(profileWith({ [case.key] = 8 }), commits[1].commands)
		assert(raced[case.key] == 8, case.key .. ": a stale attribute undid the profile's x8")
		-- Raising still works.
		table.clear(commits)
		case.fn(player, 16)
		assert(attrs[case.key] == 16, case.key .. ": attribute did not rise")
		local raised = applyAll(profileWith({ [case.key] = 8 }), commits[1].commands)
		assert(raised[case.key] == 16, case.key .. ": profile did not rise to 16")
	end
	pass("PlayerStatsBridge setters (Speed and Wins): raise-only for the attribute and the saved value, even from a stale attribute")
end

----------------------------------------------------------------------
-- f. The HUD writes neither multiplier on the client
----------------------------------------------------------------------
do
	local hud = read(HUD)
	for _, key in { "PermanentBaseSpeedMultiplier", "PermanentWinsMultiplier" } do
		assert(not hud:find('SetAttribute%(%s*"' .. key .. '"'), "MainHUDController still writes " .. key)
	end
	assert(hud:find("pendingRung.live(pendingRung.speed)", 1, true) and hud:find("pendingRung.live(pendingRung.wins)", 1, true),
		"the ladder buttons do not use the local pending rung")
	pass("MainHUDController no longer SetAttributes PermanentBaseSpeedMultiplier / PermanentWinsMultiplier (local pending rung instead)")
end

----------------------------------------------------------------------
-- g. World 3 pays the multiplier
----------------------------------------------------------------------
do
	local stage2 = Config.World3StageWinRewards[2]
	assert(stage2 == 750000, "World 3 Stage 2 pays " .. tostring(stage2))
	local pads = read(W3_PADS)
	assert(pads:find("Config.World3StageWinRewards[stage]", 1, true) and pads:find("RewardPadClaims.Claim(player, pad, reward, stage, isFinal", 1, true),
		"World 3's pads no longer pay Config.World3StageWinRewards through RewardPadClaims")

	local commits = {}
	local connection = { Connect = function() end }
	local PlayersStub = { PlayerRemoving = connection }
	local modules = {
		DataService = {
			GetHandle = function() return { userId = 1, sessionId = "s", generation = 1 } end,
			NewOperationId = function() return "op-" .. (#commits + 1) end,
			Commit = function(_, request)
				table.insert(commits, request)
				return { kind = "Committed" }
			end,
		},
		MovementGuard = { CanClaim = function() return true end, RecordFinalClaim = function() end },
		PadTouchService = {
			IsAtPad = function() return false end, -- already sent home when the claim settles
			ConsumeContact = function() return true end,
			RequestRetry = function() end,
		},
	}
	local function node(name)
		return setmetatable({ __name = name }, { __index = function(_, child) return node(child) end })
	end
	local Claims = luau.load(fs.readFile(CLAIMS), { environment = env({
		game = { GetService = function(_, name) return if name == "Players" then PlayersStub else {} end },
		script = node("RewardPadClaims"),
		require = function(ref) return assert(modules[ref.__name], "unexpected require " .. tostring(ref.__name)) end,
		_G = { SpeedsterGetWinsMultiplier = function() return 4 end },
		task = { spawn = function(fn) fn() end, delay = function() end },
		typeof = function(v) return type(v) end,
	}) })()
	local player = { Name = "OGBuyer", UserId = 1, Parent = PlayersStub, GetAttribute = function(_, k) return if k == "DataLoaded" then true else nil end }
	local paid
	local ok = Claims.Claim(player, {}, stage2, 2, false, function() return true end, function(amount) paid = amount end)
	assert(ok == true, "the claim was refused")
	assert(paid == 3000000, "World 3 Stage 2 paid " .. tostring(paid) .. " at x4")
	local grant = commits[1].commands[1]
	assert(grant.kind == "GrantExact" and grant.stat == "Wins" and grant.amount == 3000000, "the saved grant is " .. tostring(grant.amount))
	local finalPaid
	assert(Claims.Claim(player, {}, Config.World3FinalWinReward, 10, true, function() return true end, function(amount) finalPaid = amount end), "final claim refused")
	assert(finalPaid == 40000000 and commits[2].commands[1].amount == 40000000, "the World 3 finish paid " .. tostring(finalPaid) .. " at x4")
	pass("RewardPadClaims at x4: World 3 Stage 2 pays 750,000 -> 3,000,000 and the finish 10,000,000 -> 40,000,000")
end

print(("\nALL %d CHECKS PASSED"):format(passed))
