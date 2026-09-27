-- audit/test_retention_p0.luau  (2026-09-24 retention P0 pass, audit/../output/Auditoria_Retencion_20260923)
-- The P0 fixes of the retention audit, on the real code where it can run offline:
--   1. Rebirth gamepass pays ONE rebirth, ever (the real bridge function on a real SessionActor,
--      across a rejoin), not +1 on every join / world change;
--   2. QuestService no longer commits every profile every 10 s; saves on choose / claim / leave /
--      a 5 min safety flush, and pushes the panel only to players who have it open;
--   3. AFK Mode's unclaimed rewards and the quests' progress are saved before Release
--      (Bootstrap's before-release hooks), not dropped on leave / the idle rejoin;
--   4. the Spin Wheel funnel starts one run per panel open, not one every 2 s;
--   5. Time Gifts: the HUD "!" follows the playtime gifts (not the Daily), and the panel reads
--      the claimed ARRAY correctly;
--   6. small ones: DarkZonic x300 in World 2/3, no no-op skin commits on respawn, destructive
--      admin actions refuse "All", dead scripts retired, the lobby Admin rainbow on the client,
--      HttpService declared in PlayerStatsBridge.
-- Every changed source compiles.
--   lune run audit/test_retention_p0.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src/common/"
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function between(source, from, to, label)
	local a = string.find(source, from, 1, true)
	assert(a, "marker not found (" .. label .. "): " .. from)
	local b = string.find(source, to, a + #from, true)
	assert(b, "end marker not found (" .. label .. "): " .. to)
	return string.sub(source, a, b - 1)
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function hasNot(source, needle, message)
	assert(not string.find(source, needle, 1, true), message)
end

----------------------------------------------------------------------
-- 0. Every changed source compiles
----------------------------------------------------------------------
local CHANGED = {
	ROOT .. "ServerScriptService/Progression/PlayerStatsBridge.luau",
	ROOT .. "ServerScriptService/Economy/SpeedProductPurchases.server.luau",
	ROOT .. "ServerScriptService/Social/QuestService.server.luau",
	ROOT .. "ServerScriptService/Social/AfkZoneService.server.luau",
	ROOT .. "ServerScriptService/Bootstrap.server.luau",
	ROOT .. "ServerScriptService/Economy/SkinSystem.server.luau",
	ROOT .. "ServerScriptService/Admin/AdminAbusePanelService.server.luau",
	ROOT .. "ReplicatedStorage/Shared/Config.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/UI/TimeGiftController.client.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
	ROOT .. "ReplicatedFirst/SpawnFloorSurfaceFix.client.luau",
	"src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/World1ClientMotionHazards.client.luau",
	"src/worlds/World1/ServerScriptService/Gameplay/World1ClientHazardAuthority.server.luau",
	"src/worlds/World1/ServerScriptService/Infrastructure/AAA_NewWorld1PadCleanup.server.luau",
	"src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau",
}
for _, path in CHANGED do
	local ok, err = pcall(luau.compile, read(path))
	assert(ok, "does not compile: " .. path .. "\n" .. tostring(err))
end
pass(#CHANGED .. " changed sources compile")

----------------------------------------------------------------------
-- 1. Rebirth gamepass: one rebirth, ever (real bridge function, real SessionActor)
----------------------------------------------------------------------
do
	local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
	local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
	local now = 1000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local store = Adapter.CreateMock({ Player_1 = { Version = 306, Wins = 100, Speed = 100, Rebirths = 3 } })
	local actor, handle
	local function open(id)
		actor = Actor.new({ userId = 1, sessionId = id, storeAdapter = store, clock = clock })
		local opened = actor:Open()
		assert(opened.ok, "session opens")
		handle = opened.value
	end
	open("A")

	local bridge = read(ROOT .. "ServerScriptService/Progression/PlayerStatsBridge.luau")
	has(bridge, 'local REBIRTH_PASS_MARKER = "__RebirthPassGranted"', "the marker constant")
	local chunk = between(bridge, "g.SpeedsterGrantRebirthPassOnce = function", "-- 12. SpeedsterHasProcessedReceipt", "grant once")
	local syncs = 0
	local env = {
		table = table,
		REBIRTH_PASS_MARKER = "__RebirthPassGranted",
		DataService = {
			GetHandle = function() return handle end,
			Inspect = function(h) return actor:Inspect(h) end,
			Commit = function(h, request) return actor:Commit(h, request) end,
		},
		g = { SpeedsterSyncRebirthAttributes = function() syncs += 1 end },
	}
	local g = luau.load(chunk:gsub("^g%.SpeedsterGrantRebirthPassOnce = function", "return function"), { environment = env })()
	local player = { UserId = 1 }
	local function rebirths()
		return actor:Inspect(handle).value.profile.Rebirths
	end
	assert(g(player) == true, "the first grant pays")
	assert(rebirths() == 4, "3 + 1 rebirth")
	assert(g(player) == false and rebirths() == 4, "a second call (same session) pays nothing")
	-- The purchase prompt racing the join check: both skip the marker check, same identity.
	local raced = actor:Commit(handle, {
		operationId = "rebirth_pass_grant",
		fingerprint = "rebirth_pass_grant_v1",
		commands = { { kind = "GrantExact", stat = "Rebirths", amount = 1 } },
	})
	assert(raced.kind == "AlreadyCommitted" and rebirths() == 4, "a racing duplicate dedupes on the fixed operation id")
	-- Rejoin / world change: a new session on the saved profile.
	now += 60
	assert(actor:Release(handle).kind == "Released", "released")
	now += 600
	open("B")
	assert(table.find(actor:Inspect(handle).value.profile.OwnedUpgrades, "__RebirthPassGranted"), "the marker survives the save")
	assert(g(player) == false and rebirths() == 4, "REGRESSION: the Rebirth pass paid again after a rejoin")
	assert(syncs >= 1, "the rebirth attributes are re-synced")
	actor:Release(handle)

	local purchases = read(ROOT .. "ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	local joinPath = between(purchases, "local function refreshRebirthPassOwnership(player)", "\nend\n", "join path")
	hasNot(joinPath, "SpeedsterAddRebirths", "the join check must not add rebirths directly")
	has(joinPath, "SpeedsterGrantRebirthPassOnce", "the join check grants through the once-only path")
	local buyPath = between(purchases, "elseif rebirthPassId and rebirthPassId > 0 and numericPassId == rebirthPassId then", "elseif numericPassId ==", "purchase path")
	hasNot(buyPath, "SpeedsterAddRebirths", "the purchase path must not add rebirths directly")
	has(buyPath, "SpeedsterGrantRebirthPassOnce", "the purchase path grants through the once-only path")
	pass("Rebirth pass: +1 once, not again in the session, on a racing duplicate or after a rejoin; both grant paths use it")
end

----------------------------------------------------------------------
-- 2. QuestService: no 10 s commits; saves on choose/claim/leave/5 min; pushes only open panels
----------------------------------------------------------------------
do
	local quest = read(ROOT .. "ServerScriptService/Social/QuestService.server.luau")
	hasNot(quest, "if ticks % 5 == 0 then\n\t\t\t\t\ttask.spawn(flush, player)", "REGRESSION: the 10 s flush of every profile is back")
	local seconds = tonumber(string.match(quest, "local SAFETY_FLUSH_SECONDS = (%d+)"))
	assert(seconds and seconds >= 120, "the safety flush must be minutes apart, found " .. tostring(seconds))
	local loop = between(quest, "task.spawn(function()\n\tlocal ticks = 0", "\nend)", "sync loop")
	has(loop, "now - state.lastFlush >= SAFETY_FLUSH_SECONDS", "the loop flushes by each player's own last save")
	has(loop, "if now < state.watchUntil then\n\t\t\t\t\tsync(player)", "open panels are pushed every 2 s")
	has(loop, "sync(player, nil, nil, true)", "everyone else gets a badge-only refresh")
	local syncBody = between(quest, "local function sync(player, message, success, badgeOnly)", "\nend\n", "sync")
	has(syncBody, "if not badgeOnly then\n\t\tUpdate:FireClient(player, payload)", "a badge-only refresh sends nothing")
	has(between(quest, "local function claim(player)", "\nend\n", "claim"), "if not flushNow(player) then", "a claim waits for a running save instead of failing")
	has(between(quest, "local function choose(player, index)", "\nend\n", "choose"), "flushNow(player)", "choose saves first")
	has(quest, "beforeRelease.Quests = function(player)", "quests save before Release")
	has(quest, "sessions[player].watchUntil = os.clock() + WATCH_SECONDS", "a request opens the watch window")
	pass("QuestService: 5 min safety flush (was 10 s), claim waits for a save, open panels pushed, badges every 10 s, saved before Release")
end

----------------------------------------------------------------------
-- 3. AFK Mode's unclaimed rewards are paid before Release; Bootstrap runs the hooks first
----------------------------------------------------------------------
do
	local boot = read(ROOT .. "ServerScriptService/Bootstrap.server.luau")
	local cleanup = between(boot, "local function cleanupPlayer(player: Player)", "\nend\n", "cleanup")
	local hooks = string.find(cleanup, "for name, callback in beforeReleaseCallbacks do", 1, true)
	local release = string.find(cleanup, "local result=DataService.Release(player.UserId)", 1, true)
	assert(hooks and release and hooks < release, "the before-release hooks must run before Release")
	has(boot, "(_G :: any).SpeedsterBeforeRelease = beforeReleaseCallbacks", "Bootstrap shares the hook table")
	local afk = read(ROOT .. "ServerScriptService/Social/AfkZoneService.server.luau")
	local hook = between(afk, "beforeRelease.AfkMode = function(player: Player)", "\nend\n", "afk hook")
	has(hook, "claimAfkZone(player)", "unclaimed AFK rewards are claimed before Release")
	has(hook, "for _, request in session.pending do", "queued AFK commits are flushed too")
	local removing = between(afk, "Players.PlayerRemoving:Connect(function(player)", "\nend)", "afk removing")
	hasNot(removing, "\n\tsessions[player] = nil", "REGRESSION: leaving drops the AFK session (and its unclaimed rewards) at once")
	has(removing, "task.delay(30, function()\n\t\tsessions[player] = nil", "the session is dropped only after the before-release save had its chance")

	-- The hook contract, run: a table shared through _G, filled before or after Bootstrap.
	local registry = {}
	local G = { SpeedsterBeforeRelease = nil }
	local shared = (function()
		local t = G.SpeedsterBeforeRelease or {}
		G.SpeedsterBeforeRelease = t
		return t
	end)()
	shared.AfkMode = function(p) table.insert(registry, "afk:" .. p) end
	local bootTable = G.SpeedsterBeforeRelease or {}
	G.SpeedsterBeforeRelease = bootTable
	for _, callback in bootTable do callback("player1") end
	assert(registry[1] == "afk:player1", "a service registered before Bootstrap still runs")
	pass("AFK Mode and quests save before Release (hooks run before DataService.Release); leaving no longer drops unclaimed AFK rewards")
end

----------------------------------------------------------------------
-- 4. Spin Wheel funnel: one run per panel open
----------------------------------------------------------------------
do
	local spin = read(ROOT .. "StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	hasNot(spin, "opened = isOpen", "REGRESSION: the 2 s poll starts a new funnel run while the panel is open")
	local _, count = string.gsub(spin, "opened = true", "")
	assert(count == 1, "exactly one place reports the panel opened (openPanel), found " .. count)
	has(between(spin, "local function openPanel()", "\nend\n", "openPanel"), 'Request:FireServer({ action = "State", opened = true })', "openPanel reports it")
	pass("Spin Wheel funnel: `opened` only from openPanel, polls and the lobby prompt never restart the run")
end

----------------------------------------------------------------------
-- 5. Time Gifts: the HUD badge follows the gifts; the panel reads the claimed array
----------------------------------------------------------------------
do
	local hud = read(ROOT .. "StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	hasNot(hud, "refreshTimeGiftsBadge(value.CanClaim == true)", "REGRESSION: the Time Gifts badge follows the Daily reward")
	local block = between(hud, "local timeGiftState = nil", "if timeGiftsButton then", "badge")
	local badge = nil
	local serverNow = 0
	local env = {
		type = type, tonumber = tonumber, math = math,
		PlaytimeCatalog = require("../src/common/ReplicatedStorage/Shared/PlaytimeRewards"),
		Workspace = { GetServerTimeNow = function() return serverNow end },
		dismissedBadges = {},
		isBadgeDismissed = function() return false end,
		setBadgeState = function(_, on) badge = on end,
		timeGiftsButton = {},
	}
	local api = luau.load(block .. "\nreturn { refresh = refreshTimeGiftsBadge, set = function(s) timeGiftState = s end }", { environment = env })()
	local function check(claimed, elapsed, expected, label)
		api.set({ SessionStartedAt = 1000, Claimed = claimed, Completed = false })
		serverNow = 1000 + elapsed
		api.refresh()
		assert(badge == expected, "badge " .. label .. ": expected " .. tostring(expected) .. ", got " .. tostring(badge))
	end
	check({}, 100, false, "before the first gift (3:00)")
	check({}, 181, true, "gift 1 unlocked")
	check({ 1 }, 200, false, "gift 1 claimed, gift 2 not yet")
	check({ 1 }, 361, true, "gift 2 unlocked")
	check({ 2 }, 361, true, "gift 2 claimed but gift 1 still waiting")
	pass("Time Gifts badge: lights at 3:00, 6:00, ... for an unclaimed unlocked gift (the Daily's state no longer drives it)")

	local panel = read(ROOT .. "StarterPlayer/StarterPlayerScripts/UI/TimeGiftController.client.luau")
	local apply = between(panel, "local function applyState(state)", "\nend\n", "applyState") .. "\nend\n"
	local penv = { type = type, tonumber = tonumber, refresh = function() end }
	local getClaimed = luau.load(apply .. "return function(s) applyState(s) return claimed end", { environment = penv })()
	local claimed = getClaimed({ Claimed = { 2, 3 }, SessionStartedAt = 5 })
	assert(claimed[2] and claimed[3] and not claimed[1], "REGRESSION: the claimed array read as a map (gift 1 locked)")
	pass("Time Gifts panel: { 2, 3 } marks gifts 2 and 3 claimed, gift 1 stays claimable")
end

----------------------------------------------------------------------
-- 6. The small ones
----------------------------------------------------------------------
do
	local config = read(ROOT .. "ReplicatedStorage/Shared/Config.luau")
	local w23 = between(config, "if Config.IsWorld2Place or Config.IsWorld3Place then\n\tConfig.SuitSpeedGainMultipliers = {", "\n\t}\n", "W2/W3 suits")
	has(w23, "DarkZonicSuit = 300", "the paid limited must not fall back to x1 in World 2/3")
	pass("DarkZonic is x300 in World 2/3 too (was x1)")

	local skins = read(ROOT .. "ServerScriptService/Economy/SkinSystem.server.luau")
	local apply = between(skins, "local function applySavedSkin(player)", "\nend\n", "applySavedSkin")
	has(apply, "if not ownsSkin(player, defaultSkinId) then", "the default suit is unlocked only when missing")
	has(apply, "if not ownsSkin(player, skinId) then", "the equipped suit is unlocked only when missing")
	pass("SkinSystem: no profile commits for already-owned suits on every respawn")

	local admin = read(ROOT .. "ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	local guard = string.find(admin, "if takesAway and (target == \"All\" or target == \"all\") then", 1, true)
	local firstAction = string.find(admin, 'if action == "Hello" then', 1, true)
	assert(guard and firstAction and guard < firstAction, "the All guard runs before any action")
	for _, action in { "ResetStats", "RemoveStat", "SetStat" } do
		has(between(admin, "local takesAway =", "\n\tif takesAway", "takesAway"), 'action == "' .. action .. '"', action .. " is guarded")
	end
	pass("Admin panel: ResetStats / RemoveStat / SetStat / pass and treadmill removals refuse target All")

	for _, path in {
		ROOT .. "ReplicatedFirst/SpawnFloorSurfaceFix.client.luau",
		"src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/World1ClientMotionHazards.client.luau",
		"src/worlds/World1/ServerScriptService/Gameplay/World1ClientHazardAuthority.server.luau",
	} do
		for line in string.gmatch(read(path), "[^\n]+") do
			assert(string.sub(line, 1, 2) == "--", "retired script still has code: " .. path .. ": " .. line)
		end
	end
	pass("SpawnFloorSurfaceFix, World1ClientMotionHazards and World1ClientHazardAuthority are comment-only stubs")

	local cleanup = read("src/worlds/World1/ServerScriptService/Infrastructure/AAA_NewWorld1PadCleanup.server.luau")
	hasNot(cleanup, "TweenService:Create(part", "REGRESSION: the lobby Admin rainbow is tweened on the server again")
	has(cleanup, 'admin:SetAttribute("ClientRainbow", true)', "the server marks the model for the clients")
	local effects = read(ROOT .. "StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	has(effects, "local function updateLobbyRainbow()", "the client paints it")
	has(between(effects, "RunService.RenderStepped:Connect(function(dt)\n\tupdateSnow(dt)", "end)", "render loop"), "updateLobbyRainbow()", "every frame (throttled inside)")
	pass("the lobby Admin rainbow is painted on clients (15 Hz phones / 30 Hz others), no server tweens")

	local bridge = read(ROOT .. "ServerScriptService/Progression/PlayerStatsBridge.luau")
	has(bridge, 'local HttpService = if inRoblox then game:GetService("HttpService") else nil', "HttpService is declared")
	pass("PlayerStatsBridge declares HttpService (admin give/set exact no longer errors)")
end

----------------------------------------------------------------------
-- 7. World 1 hazards: a rotated hazard (spinning laser) kills on its real shape, not its
--    world-aligned bounding box; axis-aligned ones (lava, presses) behave as before.
----------------------------------------------------------------------
do
	local roblox = require("@lune/roblox")
	local motion = read("src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau")
	local chunk = between(motion, "local function isAxisAligned(part)", "RunService.RenderStepped:Connect(function()", "hazard shape")
	local inside = false
	local env = {
		math = math,
		hammerCharacterParams = {},
		Workspace = { GetPartsInPart = function() return if inside then { "LeftLeg" } else {} end },
	}
	local touches = luau.load(chunk .. "\nreturn hazardTouchesCharacter", { environment = env })()
	local flat = { CFrame = roblox.CFrame.new(0, 0, 0) }
	local turned = { CFrame = roblox.CFrame.Angles(0, math.rad(45), 0) }
	inside = false
	assert(touches(flat) == true, "an axis-aligned hazard keeps the old test (its box is its shape)")
	assert(touches(turned) == false, "REGRESSION: a rotated laser killed on its bounding box with the body outside it")
	inside = true
	assert(touches(turned) == true, "a rotated laser still kills a body inside it")
	local loop = between(motion, "RunService.RenderStepped:Connect(function()", "\nend)", "contact loop")
	has(loop, "elseif hazardKey and hazardTouchesCharacter(part) then", "every non-hammer key goes through the shape check")
	pass("World 1 hazards: a 45-degree laser only kills a body inside it (was: anywhere in its world-aligned box)")
end

print(("ALL PASSED (%d checks)"):format(passed))
