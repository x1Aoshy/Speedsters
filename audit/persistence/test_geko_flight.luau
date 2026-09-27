local fs = require("@lune/fs")

local function check(cond, msg)
	if not cond then
		error("TEST FAILURE: " .. msg, 2)
	end
end

print("=== RUNNING GEKO FLIGHT & GIVEAWAY SUITE ===")

local worlds = { "World1", "World2" }

for _, world in ipairs(worlds) do
	print("Testing " .. world .. "...")
	local catalogPath = "audit/merged/" .. world .. "/ReplicatedStorage/Shared/Catalogs/CodesCatalog.luau"
	local catalogSrc = fs.readFile(catalogPath)
	
	-- 1. Every giveaway code was retired; BOOST is the only one left. The grant
	-- machinery below still has to work, because a future code will use it.
	local retired = { "gekkoh", "geko", "gekofly", "gekogiveaway", "gekogaveyoufly", "fly20", "admingiveawayfly" }
	for _, alias in ipairs(retired) do
		check(not string.find(catalogSrc, "\n\t" .. alias .. "%s*="), world .. " retired code still in CodesCatalog: " .. alias)
	end
	check(string.find(catalogSrc, "\n\tboost%s*="), world .. " CodesCatalog must keep BOOST live")
	check(string.find(catalogSrc, "Code_Boost_v1"), world .. " CodesCatalog missing Code_Boost_v1 marker")

	-- 2. Check CodesSystem
	local codesSysPath = "audit/merged/" .. world .. "/ServerScriptService/Social/CodesSystem.luau"
	local codesSysSrc = fs.readFile(codesSysPath)
	check(string.find(codesSysSrc, "TemporaryFlight"), world .. " CodesSystem missing TemporaryFlight grant")
	-- Codes commit the flight buff atomically with the redemption marker and stats.
	check(string.find(codesSysSrc, 'kind = "GrantBuff"', 1, true)
		and string.find(codesSysSrc, 'kind = "TemporaryFlight"', 1, true)
		and string.find(codesSysSrc, 'DataService.Commit', 1, true), world .. " CodesSystem missing atomic flight grant")

	-- 3. Check ProfileCodec
	local codecPath = "audit/merged/" .. world .. "/ServerScriptService/Services/Data/ProfileCodec.luau"
	local codecSrc = fs.readFile(codecPath)
	check(string.find(codecSrc, "TemporaryFlightRemainingSeconds"), world .. " ProfileCodec missing TemporaryFlightRemainingSeconds")

	-- 4. Check ProfileReducers
	local reducersPath = "audit/merged/" .. world .. "/ServerScriptService/Services/Data/ProfileReducers.luau"
	local reducersSrc = fs.readFile(reducersPath)
	check(string.find(reducersSrc, "TemporaryFlight"), world .. " ProfileReducers missing TemporaryFlight in GrantBuff")

	-- 5. Check SessionActor
	local sessionActorPath = "audit/merged/" .. world .. "/ServerScriptService/Services/Data/SessionActor.luau"
	local sessionActorSrc = fs.readFile(sessionActorPath)
	check(string.find(sessionActorSrc, "TemporaryFlightRemainingSeconds"), world .. " SessionActor missing TemporaryFlightRemainingSeconds")

	-- 6. Check PlayerStats
	local playerStatsPath = "audit/merged/" .. world .. "/ServerScriptService/Progression/PlayerStats.luau"
	local playerStatsSrc = fs.readFile(playerStatsPath)
	check(string.find(playerStatsSrc, "TemporaryFlightRemainingSeconds"), world .. " PlayerStats missing TemporaryFlightRemainingSeconds")
	check(string.find(playerStatsSrc, "TemporaryFlightExpireUnix"), world .. " PlayerStats missing TemporaryFlightExpireUnix")

	-- 7. Check PotionServer
	local potionServerPath = "audit/merged/" .. world .. "/ServerScriptService/Services/PotionServer.luau"
	local potionServerSrc = fs.readFile(potionServerPath)
	check(string.find(potionServerSrc, "GrantTemporaryFlight"), world .. " PotionServer missing GrantTemporaryFlight")
	check(string.find(potionServerSrc, "GetRemainingTemporaryFlightSeconds"), world .. " PotionServer missing GetRemainingTemporaryFlightSeconds")

	-- 8. Check FlightAbility (Server & Client)
	local flightServerPath = "audit/merged/" .. world .. "/ServerScriptService/Core/Abilities/FlightService.luau"
	local flightServerSrc = fs.readFile(flightServerPath)
	check(string.find(flightServerSrc, "TemporaryFlightExpireUnix"), world .. " FlightServer missing TemporaryFlightExpireUnix")
	check(string.find(flightServerSrc, "Temporary Flight has expired"), world .. " FlightServer missing expiration watchdog")

	local flightClientPath = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/" .. (if world == "World1" then "World1FlightAbility.luau" else "World2FlightAbility.luau")
	local flightClientSrc = fs.readFile(flightClientPath)
	check(string.find(flightClientSrc, "hasTemporaryFlight"), world .. " FlightClient missing hasTemporaryFlight")

	-- 9. Check MainHUDController
	local hudPath = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.luau"
	local hudSrc = fs.readFile(hudPath)
	check(string.find(hudSrc, "FlightBuffCard"), world .. " MainHUDController missing FlightBuffCard")
	check(string.find(hudSrc, "TemporaryFlightExpireUnix"), world .. " MainHUDController missing TemporaryFlightExpireUnix listener")

	-- 10. Check BoostNotifier
	local notifierPath = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Gameplay/BoostNotifier.luau"
	local notifierSrc = fs.readFile(notifierPath)
	check(string.find(notifierSrc, "TemporaryFlight"), world .. " BoostNotifier missing TemporaryFlight")

	-- 11. The Gekkoh giveaway was taken out of the admin panel on request (2026-09-17); the
	-- temporary flight it granted stays available to potions and the flight shop above.
	local adminCtrlPath = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.luau"
	local adminCtrlSrc = fs.readFile(adminCtrlPath)
	check(not string.find(adminCtrlSrc, "GekoFlyGiveaway", 1, true), world .. " AdminAbusePanelController still offers the Gekkoh giveaway")
end

print("ALL GEKO FLIGHT & GIVEAWAY CHECKS PASSED PERFECTLY!")
