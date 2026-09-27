-- test_admin_abuse_panel.luau
-- The basic Admin Abuse Panel: every card the brief lists has a server action, every
-- character effect has a client handler, permission is checked before anything runs,
-- and moderation cannot be turned on other admins.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")

local service = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end

-- 1. The brief's structure.
has(controller, 'Title = "Admin Abuse Panel"', "Window title")
has(controller, '{ "Server", "This Server" }, { "All", "All Servers" }', "This Server / All Servers toggle")
has(controller, '"👥 Everyone / All"', "Everyone button at the top of the sidebar")
has(controller, "GetUserThumbnailAsync", "Sidebar rows show avatars")
for _, tab in { "Abuse/Trolls", "Events", "Boosts & Mults", "Treadmills", "Music", "Announcements", "Moderation" } do
	has(controller, '"' .. tab .. '"', "Tab " .. tab)
end
for _, card in { "Rocket", "Ragdoll", "Jail", "Balloon", "Tiny", "Inverse", "Control", "Jumpscare", "NoGravity", "Snail", "FakeReset" } do
	has(controller, '"' .. card .. '" }', "Abuse card " .. card)
	has(service, card .. " = true", "Server action for " .. card)
end
for _, event in { "Disco", "Sandstorm", "Confetti", "Fireworks", "RainingTacos", "MegaRace" } do
	has(controller, '"' .. event .. '"', "Event card " .. event)
	has(service, event .. " = true", "Server event " .. event)
end
-- Update 4 (2026-09-25): seven event tiles now, Mega Race last; every tile has its server event.
do
	local events = assert(string.match(service, "local EVENTS = {(.-)}\n"), "EVENTS")
	local serverEvents = {}
	for name in string.gmatch(events, "(%w+) = true") do
		serverEvents[name] = true
	end
	local tiles = assert(string.match(controller, "function TABS%.Events%(page%)(.-)\nend\n"), "Events tab")
	local count = 0
	for name in string.gmatch(tiles, '{ "[^"]+", "(%w+)", "[^"]+", "[^"]+", "%w+" }') do
		count += 1
		assert(serverEvents[name], "Event tile " .. name .. " has a server event")
	end
	assert(count == 7, "Seven event tiles (" .. count .. ")")
	has(controller, '{ "🏁", "MegaRace", "Mega Race", "x2 race rewards, 16 racers, starts now", "Blue" },', "Mega Race tile")
	has(controller, '{ "StaminaRegen", "2x Stamina" },', "2x Stamina pass toggle")
	has(service, "StaminaRegen = true", "Server pass StaminaRegen")
	for _, action in { "GrantTitle", "RevokeTitle", "SetCommunityCode" } do
		has(service, 'action == "' .. action .. '"', "Server handles " .. action)
	end
end
for _, quick in { '"2x Speed", "Speed", 2', '"4x Speed", "Speed", 4', '"2x Wins", "Wins", 2', '"5x Wins", "Wins", 5' } do
	has(controller, quick, "Quick boost " .. quick)
end
for _, action in { "Kick", "Ban", "Unban", "Mute", "Unmute", "GoTo", "Bring", "GiveSpeed", "RemoveSpeed", "GiveStat", "RemoveStat", "SetStat", "WipeData", "Announce", "PlayMusic", "StopMusic", "Treadmill", "ClearTreadmills", "Boost" } do
	has(service, 'action == "' .. action .. '"', "Server handles " .. action)
end
has(service, "Players:UnbanAsync({", "Unbans use Roblox's unban API")
has(controller, "COOLDOWN_SECONDS", "Cards show a cooldown")
has(controller, "Enum.KeyCode.F2", "F2 opens the panel")
print("PASS panel layout: header, scope toggle, sidebar, seven tabs and every card the brief lists")

-- 2. Safety.
local handler = string.match(service, "Panel.OnServerEvent:Connect%(function%(admin: Player, payload: any%)(.-)\nend%)")
assert(handler, "Request handler not found")
local permission = string.find(handler, "if not isAllowed(admin) then", 1, true)
local firstAction = string.find(handler, 'if action == "Hello" then', 1, true)
assert(permission and firstAction and permission < firstAction, "Permission must be checked before any action runs")
has(handler, 'RateLimiter.Allow(admin, "AdminAbusePanel", 0.3)', "Requests are rate limited")
has(handler, 'isAllowed(victim) and (action == "Kick" or action == "Ban" or action == "Mute")', "Admins cannot be kicked, banned or muted here")
has(handler, "Validation.FilterBroadcast(TextService, admin.UserId", "Announcements are filtered")
has(service, "Players:BanAsync({", "Bans use Roblox's ban API")
has(service, "MessagingService:SubscribeAsync(TOPIC", "All Servers reaches the other servers")
has(service, "payload.OriginJobId == game.JobId", "A server ignores its own broadcast")
print("PASS safety: permission first, rate limit, filtered text, admins protected, cross-server dedupe")

-- 3. Every character effect the server sends has a client handler.
local clientEffects = string.match(service, "local CLIENT_EFFECTS = {(.-)}")
assert(clientEffects, "CLIENT_EFFECTS not found")
for name in string.gmatch(clientEffects, "(%w+) = true") do
	has(effects, "function EFFECTS." .. name .. "(", "Client handler for " .. name)
end
for _, broadcast in { "Sandstorm", "Confetti", "Fireworks" } do
	has(effects, "function EFFECTS." .. broadcast .. "(", "Client handler for " .. broadcast)
end
print("PASS effects: every client-side effect has a handler")

-- 4. Remove Speed persists and never goes below zero.
do
	local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
	local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
	local now = 7000000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local store = Adapter.CreateMock({ Player_31 = { Version = 306, Speed = 5000, Wins = 0 } })
	local actor = Actor.new({ userId = 31, sessionId = "debit", storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok)
	local function debit(id, amount)
		return actor:Commit(opened.value, { operationId = id, fingerprint = id, commands = { { kind = "DebitSpeed", amount = amount } } })
	end
	assert(debit("d1", 1200).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.Speed == 3800, "Speed drops by the amount")
	assert(debit("d2", 1e9).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.Speed == 0, "Speed never goes below zero")
	assert(debit("d3", -5).kind == "Rejected", "Negative debits are refused")
	print("PASS Remove Speed: persistent, floored at zero, rejects bad amounts")

	-- 5. ResetStats resets Speed, Wins and Rebirths back to baseline.
	local function resetStats(id)
		return actor:Commit(opened.value, { operationId = id, fingerprint = id, commands = { { kind = "ResetStats", resetSpeedTo = 1 } } })
	end
	assert(resetStats("r1").kind == "Committed")
	local profileAfterReset = actor:Inspect(opened.value).value.profile
	assert(profileAfterReset.Speed == 1, "Speed resets to 1")
	assert(profileAfterReset.Wins == 0, "Wins reset to 0")
	assert(profileAfterReset.Rebirths == 0, "Rebirths reset to 0")
	print("PASS ResetStats: sets Speed=1, Wins=0, Rebirths=0 in durable store")

	-- 5b. DebitStat, SetStat, and WipeProfile operations
	local function setStat(id, stat, amount)
		return actor:Commit(opened.value, { operationId = id, fingerprint = id, commands = { { kind = "SetStat", stat = stat, amount = amount } } })
	end
	local function debitStat(id, stat, amount)
		return actor:Commit(opened.value, { operationId = id, fingerprint = id, commands = { { kind = "DebitStat", stat = stat, amount = amount } } })
	end
	local function wipeProfile(id)
		return actor:Commit(opened.value, { operationId = id, fingerprint = id, commands = { { kind = "WipeProfile", resetSpeedTo = 1 } } })
	end

	assert(setStat("s1", "Wins", 500).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.Wins == 500, "SetStat sets Wins")
	assert(debitStat("db1", "Wins", 150).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.Wins == 350, "DebitStat reduces Wins")

	assert(setStat("s2", "SpinTickets", 25).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.SpinTickets == 25, "SetStat sets SpinTickets")
	assert(debitStat("db2", "SpinTickets", 10).kind == "Committed")
	assert(actor:Inspect(opened.value).value.profile.SpinTickets == 15, "DebitStat reduces SpinTickets")

	assert(wipeProfile("wp1").kind == "Committed")
	local wiped = actor:Inspect(opened.value).value.profile
	assert(wiped.Speed == 1, "WipeProfile resets Speed to 1")
	assert(wiped.Wins == 0, "WipeProfile resets Wins to 0")
	assert(wiped.Rebirths == 0, "WipeProfile resets Rebirths to 0")
	assert(wiped.SpinTickets == 0, "WipeProfile resets SpinTickets to 0")
	print("PASS SetStat, DebitStat, and WipeProfile: full data mutations verified")
end

-- 6. Snow, the disco ball and the admin treadmill, on the real places.
do
	local luau = require("@lune/luau")
	local roblox = require("@lune/roblox")
	local function chunkBetween(first, last)
		local a = assert(string.find(service, first, 1, true), "service chunk " .. first)
		local b = assert(string.find(service, last, a, true), "service chunk end " .. last)
		return string.sub(service, a, b - 1)
	end
	local function environment(place, extra)
		local delays = {}
		local env = setmetatable({
			Workspace = place:GetService("Workspace"),
			ServerStorage = place:GetService("ServerStorage"),
			HttpService = { GenerateGUID = function()
				return tostring(math.random())
			end },
			task = {
				delay = function(seconds, callback)
					table.insert(delays, { Seconds = seconds, Callback = callback })
				end,
				-- Work started in the background (the DJ's avatar) waits to be run by the check.
				spawn = function() end,
			},
			eventTokens = {},
			Instance = roblox.Instance,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequence = roblox.NumberSequence,
			NumberRange = roblox.NumberRange,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			-- The Disco perk's dance reports (AdminDiscoDance), wired but never fired here.
			remote = function()
				return { OnServerEvent = { Connect = function() end } }
			end,
			RateLimiter = { Allow = function() return true end },
			Players = { GetPlayers = function() return {} end, PlayerRemoving = { Connect = function() end } },
		}, { __index = _G })
		for key, value in extra or {} do
			env[key] = value
		end
		return env, delays
	end

	-- ❄️ Snow: lava turns to ice and stops burning, bosses freeze, and all of it comes back.
	local snowChunk = chunkBetween("local frozenParts", "local function stopEvent")
	for _, file in PlaceFiles.Files() do
		local place = roblox.deserializePlace(fs.readFile(file))
		local workspace = place:GetService("Workspace")
		local env, delays = environment(place)
		local startSnow, stopSnow = luau.load(snowChunk .. "\nreturn startSnow, stopSnow", { environment = env })()
		local lava, decor, before, looks, bosses = {}, {}, {}, {}, {}
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "lava", 1, true) and not descendant:FindFirstChild("Kill script") and not descendant:FindFirstChildOfClass("Texture") and not descendant:FindFirstChildOfClass("SurfaceLight") and descendant.Material ~= roblox.Enum.Material.CrackedLava then
				-- Named lava but dressed as something else (the desert's minecart sand): not lava.
				table.insert(decor, descendant)
				before[descendant] = { descendant.Material, descendant.Color }
			elseif descendant:IsA("BasePart") and (descendant:FindFirstChild("Kill script") or string.find(string.lower(descendant.Name), "lava", 1, true)) then
				table.insert(lava, descendant)
				before[descendant] = { descendant.Material, descendant.Color }
				for _, child in descendant:GetDescendants() do
					if child:IsA("Texture") or child:IsA("Decal") then
						looks[child] = { Transparency = child.Transparency }
					elseif child:IsA("SurfaceLight") or child:IsA("PointLight") or child:IsA("SpotLight") then
						looks[child] = { Color = child.Color, Brightness = child.Brightness }
					end
				end
			elseif descendant:IsA("Model") and (descendant.Name == "Zoom" or descendant.Name == "ReverseFlashBoss" or descendant.Name == "Sonic.EXE") then
				table.insert(bosses, descendant)
			end
		end
		assert(#lava > 0 and next(looks), file .. " has lava with its lava texture and glow")
		assert(file == PlaceFiles.World3 or #bosses > 0, file .. " has a boss to freeze")
		startSnow(60)
		assert(workspace:GetAttribute("AdminWorldFrozen") == true and workspace:GetAttribute("AdminSnowUntil"), file .. ": the world is frozen while it snows")
		for _, part in lava do
			assert(part.Material == roblox.Enum.Material.Ice and part.Color == roblox.Color3.fromRGB(165, 220, 255), file .. ": " .. part:GetFullName() .. " turned to ice")
			assert(part:FindFirstChild("AdminIceSparkles"), file .. ": " .. part:GetFullName() .. " sparkles like ice")
			assert(part:GetAttribute("AdminFrozenLava") == true, file .. ": " .. part:GetFullName() .. " is marked as ice for every client")
		end
		for object, saved in looks do
			if saved.Transparency then
				assert(object.Transparency == 1, file .. ": the lava texture " .. object:GetFullName() .. " is hidden on the ice")
			else
				assert(object.Color == roblox.Color3.fromRGB(170, 225, 255) and object.Brightness < saved.Brightness, file .. ": the lava glow " .. object:GetFullName() .. " turns cold and dim")
			end
		end
		for _, part in decor do
			assert(part.Material == before[part][1] and part.Color == before[part][2] and not part:FindFirstChild("AdminIceSparkles"), file .. ": " .. part:GetFullName() .. " is decor, not lava, and stays as it is")
		end
		for _, boss in bosses do
			assert(boss:FindFirstChild("AdminFrozen") and boss:GetAttribute("AdminFrozen") == true, file .. ": " .. boss.Name .. " is frozen")
		end
		startSnow(60) -- a second start while frozen neither stacks ice nor loses the lava's look
		assert(delays[#delays] and delays[#delays].Seconds == 60, "The snow ends on its own")
		delays[#delays].Callback()
		assert(workspace:GetAttribute("AdminWorldFrozen") == nil and workspace:GetAttribute("AdminSnowUntil") == nil, file .. ": the thaw")
		for _, part in lava do
			assert(part.Material == before[part][1] and part.Color == before[part][2], file .. ": " .. part:GetFullName() .. " is lava again")
			assert(not part:FindFirstChild("AdminIceSparkles"), file .. ": " .. part:GetFullName() .. " loses its sparkles")
			assert(part:GetAttribute("AdminFrozenLava") == nil, file .. ": " .. part:GetFullName() .. " is lava again for every client")
		end
		for object, saved in looks do
			for property, value in saved do
				assert(object[property] == value, file .. ": " .. object:GetFullName() .. "." .. property .. " is back exactly")
			end
		end
		for _, boss in bosses do
			assert(not boss:FindFirstChild("AdminFrozen") and boss:GetAttribute("AdminFrozen") == nil, file .. ": " .. boss.Name .. " thawed")
		end
		startSnow(30)
		stopSnow()
		assert(workspace:GetAttribute("AdminWorldFrozen") == nil and lava[1].Material == before[lava[1]][1], file .. ": turning snow off early thaws too")
		for object, saved in looks do
			for property, value in saved do
				assert(object[property] == value, file .. ": " .. object:GetFullName() .. "." .. property .. " is back after an early stop")
			end
		end
	end
	-- What reads the freeze: every lava kill script, World 1's rising lava, and the bosses.
	for _, file in PlaceFiles.Files() do
		local place = roblox.deserializePlace(fs.readFile(file))
		local kills = 0
		for _, descendant in place:GetService("Workspace"):GetDescendants() do
			if descendant:IsA("Script") and descendant.Name == "Kill script" then
				kills += 1
				assert(string.find(descendant.Source, 'if workspace:GetAttribute("AdminWorldFrozen") == true then return end', 1, true), file .. ": " .. descendant:GetFullName() .. " spares frozen lava")
			end
		end
		assert(kills > 0, file .. " has lava kill scripts")
	end
	for _, path in {
		"src/common/ServerScriptService/Bosses/ZoomBoss.server.luau",
		"src/worlds/World1/ServerScriptService/Bosses/ReverseFlashBoss.server.luau",
		"src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau",
	} do
		local source = fs.readFile(path)
		local heartbeat = assert(string.find(source, "heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)", 1, true))
		local frozen = assert(string.find(source, 'if Workspace:GetAttribute("AdminWorldFrozen") == true then', heartbeat, true), path .. " stops while frozen")
		assert(frozen - heartbeat < 600, path .. ": the freeze check is at the top of the boss's loop")
	end
	local motion = fs.readFile("src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau")
	has(motion, 'if lavaFrozen and (group.HazardKey == "LavaUp" or group.HazardKey == "Lava") then', "World 1's lava stops burning while frozen")
	has(motion, 'if Workspace:GetAttribute("AdminWorldFrozen") ~= true then\n\t\t\tupdateLavaUp(serverTime)', "...and stops rising")
	-- Ice never kills on the client either, and a death only a client saw still respawns.
	do
		local run = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau")
		local touch = assert(string.find(run, "local function setupLethalTouchPrediction", 1, true), "The character's lava prediction")
		local skip = assert(string.find(run, 'if isLethal and (hitPart:GetAttribute("AdminFrozenLava") == true', touch, true), "The character's lava prediction leaves frozen lava alone")
		local kill = assert(string.find(run, "humanoid.Health = 0", touch, true))
		assert(skip < kill, "...before it would kill")
		has(run, 'and (string.find(nameLower, "lava", 1, true) ~= nil or string.find(parentLower, "lava", 1, true) ~= nil)))', "...even lava the server has not marked yet")
		has(run, 'if character.Parent and localPlayer.Character == character and character:GetAttribute("Dead") ~= true then', "A death the server never saw asks for a real one")
		-- Update 4 H6 (p0_gameplay) moves this ask to the LocalDeathClaim remote (the server's
		-- arbiter decides); until that lands the reset remote still carries it.
		assert(string.find(run, 'remotes:FindFirstChild("LocalDeathClaim"', 1, true)
			or string.find(run, 'remotes:WaitForChild("LocalDeathClaim"', 1, true)
			or string.find(run, 'local reset = remotes and remotes:FindFirstChild("PlayerResetRequest")', 1, true), "...through the death-claim (or reset) remote")
		local motion = fs.readFile("src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau")
		local motionKill = assert(string.find(motion, "local function killLocalForHazard(hazardKey)", 1, true))
		local motionSkip = assert(string.find(motion, 'if (hazardKey == "Lava" or hazardKey == "LavaUp") and Workspace:GetAttribute("AdminWorldFrozen") == true then', motionKill, true), "World 1's moving lava leaves the frozen player alone")
		assert(motionSkip < assert(string.find(motion, "humanoid.Health = 0", motionKill, true)), "...before it would kill")
		local bootstrap = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
		has(bootstrap, 'getOrCreateRemote("PlayerResetRequest")', "The reset remote exists from the start (only the retired admin panel made it before)")
		local ragdoll = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau")
		assert(string.find(ragdoll, "if sender == myPlayer and humanoid and humanoid%.Health > 0 then%s+humanoid%.Health = 0"), "The server kills the asking player for real, and they respawn")
		-- Every client script that kills its own character on touching lava knows about ice.
		for _, root in { "src/common", "src/worlds" } do
			local function walk(path)
				for _, name in fs.readDir(path) do
					local full = path .. "/" .. name
					if fs.isDir(full) then
						walk(full)
					elseif string.sub(name, -12) == ".client.luau" then
						local source = fs.readFile(full)
						if string.find(source, "Health = 0", 1, true) and string.find(string.lower(source), "lava", 1, true) then
							assert(string.find(source, "AdminWorldFrozen", 1, true) or string.find(source, "AdminFrozenLava", 1, true), full .. " kills on lava but does not know about frozen lava")
						end
					end
				end
			end
			walk(root)
		end
	end
	print("PASS Snow: lava (texture, glow and all) turns to ice and spares players on every client, deaths always respawn, decor stays, bosses freeze, and everything thaws back exactly")

	-- 🪩 Disco: the party marked over each lobby's flat dance floor, the ball high over it
	-- with room to hang, gone when it ends.
	local discoChunk = chunkBetween("local function lobbyCenter", "local function startSandstorm")
	local discoConfigSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
	local discoConfigStart = assert(string.find(discoConfigSource, "Config.AdminDisco = {", 1, true))
	local discoConfigEnd = assert(string.find(discoConfigSource, "\n}\n", discoConfigStart, true))
	local AdminDisco = luau.load(
		"local Config = {}\n" .. string.sub(discoConfigSource, discoConfigStart, discoConfigEnd) .. "}\nreturn Config.AdminDisco",
		{ environment = setmetatable({ Vector3 = roblox.Vector3 }, { __index = _G }) }
	)()
	local function partCorners(part)
		local half = part.Size / 2
		local list = {}
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(list, part.CFrame:PointToWorldSpace(roblox.Vector3.new(half.X * x, half.Y * y, half.Z * z)))
				end
			end
		end
		return list
	end
	for _, world in { { "World1", PlaceFiles.World1, { IsNewWorld1Map = true } }, { "World2", PlaceFiles.World2, { IsWorld2Place = true } }, { "World3", PlaceFiles.World3, { IsWorld3Place = true } } } do
		local key, file = world[1], world[2]
		local lobby = roblox.deserializePlace(fs.readFile(file))
		local lobbyWorkspace = lobby:GetService("Workspace")
		local config = { AdminDisco = AdminDisco }
		for flag, value in world[3] do
			config[flag] = value
		end
		local discoEnv, discoDelays = environment(lobby, { Config = config })
		local startDisco, stopDisco = luau.load(discoChunk .. "\nreturn startDisco, stopDisco", { environment = discoEnv })()
		local spot = assert(AdminDisco.WorldPlacement[key], key .. " has a dance floor")
		startDisco(90)
		assert(lobbyWorkspace:GetAttribute("AdminDiscoFloor") == spot.Floor and lobbyWorkspace:GetAttribute("AdminDiscoFloorSize") == spot.Size, key .. ": every client knows where the dance floor is")
		assert(lobbyWorkspace:GetAttribute("AdminDiscoCenter") == spot.Floor + roblox.Vector3.new(0, AdminDisco.BallHeight, 0), key .. ": the ball hangs over the middle of the floor")
		assert(lobbyWorkspace:GetAttribute("AdminDiscoUntil") and discoDelays[#discoDelays].Seconds == 90, key .. ": it ends on its own")
		assert(not lobbyWorkspace:FindFirstChild("AdminDiscoBall"), key .. ": the server builds no ball of its own; every client draws it")

		-- The dance floor is the lobby floor: flat all over, at the spot's height.
		local floorParts = {}
		for _, part in lobbyWorkspace:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide and part ~= lobbyWorkspace.Terrain then
				local top = -math.huge
				for _, corner in partCorners(part) do
					top = math.max(top, corner.Y)
				end
				if top < spot.Floor.Y + 3 and top > spot.Floor.Y - 15 then
					table.insert(floorParts, { part, top })
				end
			end
		end
		local samples, flat = 0, 0
		for x = -spot.Size.X / 2, spot.Size.X / 2, 4 do
			for z = -spot.Size.Z / 2, spot.Size.Z / 2, 4 do
				local point = spot.Floor + roblox.Vector3.new(x, 0, z)
				local best = -math.huge
				for _, entry in floorParts do
					local localPoint = entry[1].CFrame:PointToObjectSpace(point)
					if math.abs(localPoint.X) <= entry[1].Size.X / 2 and math.abs(localPoint.Z) <= entry[1].Size.Z / 2 then
						best = math.max(best, entry[2])
					end
				end
				samples += 1
				if math.abs(best - spot.Floor.Y) < 0.05 then
					flat += 1
				end
			end
		end
		assert(flat / samples >= 0.97, key .. ": the dance floor is flat lobby floor (" .. flat .. "/" .. samples .. ")")

		-- Room for the ball: nothing of the map where it hangs or on its way down.
		local center = spot.Floor + roblox.Vector3.new(0, AdminDisco.BallHeight, 0)
		for _, part in lobbyWorkspace:GetDescendants() do
			if part:IsA("BasePart") and part ~= lobbyWorkspace.Terrain and part.Transparency < 1 then
				for _, corner in partCorners(part) do
					local offset = corner - center
					assert(not (math.abs(offset.X) < 14 and math.abs(offset.Z) < 14 and offset.Y > -14 and offset.Y < 60), key .. ": " .. part:GetFullName() .. " is where the ball hangs")
				end
			end
		end

		startDisco(30)
		stopDisco()
		for _, name in { "AdminDiscoUntil", "AdminDiscoCenter", "AdminDiscoFloor", "AdminDiscoFloorSize" } do
			assert(lobbyWorkspace:GetAttribute(name) == nil, key .. ": turning it off clears " .. name)
		end
	end
	local place = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
	print("PASS Disco: marked over each lobby's flat dance floor with room for the ball, drawn by every client, gone when it ends")

	-- 🎧 The DJ booth: on each lobby's booth spot (clear, flat, under any overhang), built
	-- facing the dance floor, the admin's avatar dancing on it with their name over their
	-- head, lit in time by every client, and faded away in confetti when the party ends.
	do
		local V3 = roblox.Vector3
		local function lookAt(at, target)
			local look = (target - at).Unit
			local up = V3.new(0, 1, 0)
			if math.abs(look:Dot(up)) > 0.9999 then
				up = V3.new(0, 0, 1)
			end
			local right = look:Cross(up).Unit
			return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
		end
		local CFrameRoblox = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })
		local function chunkBetweenIn(source, first, last)
			local a = assert(string.find(source, first, 1, true), "chunk " .. first)
			local b = assert(string.find(source, last, a, true), "chunk end " .. last)
			return string.sub(source, a, b - 1)
		end
		-- The set, in units of its scale (AdminAbusePanelService): the console's top, the
		-- DJ's chest, the console's front, the footprint and the tower under the stage.
		local U = assert(AdminDisco.BoothScale, "The booth has a scale")
		assert(U >= 4, "The booth is giant (" .. U .. "x)")
		local DESK_TOP, CHEST, HEAD, DESK_FRONT, STAND_Z = 6.0, 8.2, 10.2, -2.4, 0.3
		local HALF_W, HALF_D, TOWER, TOP = 12, 5, 40, 18

		-- Each spot is out past its lobby's back wall, clear of the map, and from the dance
		-- floor the wall hides the stage while the DJ shows over the console.
		for _, world in { { "World1", PlaceFiles.World1 }, { "World2", PlaceFiles.World2 }, { "World3", PlaceFiles.World3 } } do
			local key, file = world[1], world[2]
			local booth = assert(AdminDisco.WorldPlacement[key].Booth, key .. " has a DJ booth spot")
			local floorSpot = AdminDisco.WorldPlacement[key].Floor
			local floorSize = AdminDisco.WorldPlacement[key].Size
			local face = ((booth.Face - booth.Position) * V3.new(1, 0, 1)).Unit
			assert(face:Dot(((floorSpot - booth.Position) * V3.new(1, 0, 1)).Unit) > 0.99, key .. ": the DJ faces the dance floor")
			local frame = lookAt(booth.Position, V3.new(booth.Face.X, booth.Position.Y, booth.Face.Z))
			local lobby = roblox.deserializePlace(fs.readFile(file))
			local boxes = {}
			for _, part in lobby:GetService("Workspace"):GetDescendants() do
				if part:IsA("BasePart") and part.ClassName ~= "Terrain" and part.Transparency < 0.95 then
					local low, high = V3.new(math.huge, math.huge, math.huge), V3.new(-math.huge, -math.huge, -math.huge)
					for _, c in partCorners(part) do
						low = V3.new(math.min(low.X, c.X), math.min(low.Y, c.Y), math.min(low.Z, c.Z))
						high = V3.new(math.max(high.X, c.X), math.max(high.Y, c.Y), math.max(high.Z, c.Z))
					end
					table.insert(boxes, { Min = low, Max = high, Part = part })
				end
			end
			-- Nothing of the map stands in the booth, from its tower's foot to its truss.
			for _, box in boxes do
				if box.Max.Y > booth.Position.Y - TOWER * U and box.Min.Y < booth.Position.Y + TOP * U then
					local a, b = math.huge, -math.huge
					local c, d = math.huge, -math.huge
					for _, x in { box.Min.X, box.Max.X } do
						for _, z in { box.Min.Z, box.Max.Z } do
							local rel = frame:PointToObjectSpace(V3.new(x, booth.Position.Y, z))
							a, b = math.min(a, rel.X), math.max(b, rel.X)
							c, d = math.min(c, rel.Z), math.max(d, rel.Z)
						end
					end
					local overlaps = b > -HALF_W * U and a < HALF_W * U and d > -HALF_D * U and c < HALF_D * U
					assert(not overlaps, key .. ": " .. box.Part:GetFullName() .. " stands where the booth goes")
				end
			end
			local function blocked(from, to)
				local dir = to - from
				for _, box in boxes do
					local t0, t1 = 0, 1
					local hit = true
					for _, axis in { "X", "Y", "Z" } do
						local da = dir[axis]
						if math.abs(da) < 1e-9 then
							if from[axis] < box.Min[axis] or from[axis] > box.Max[axis] then
								hit = false
								break
							end
						else
							local ta, tb = (box.Min[axis] - from[axis]) / da, (box.Max[axis] - from[axis]) / da
							if ta > tb then
								ta, tb = tb, ta
							end
							t0, t1 = math.max(t0, ta), math.min(t1, tb)
							if t0 > t1 then
								hit = false
								break
							end
						end
					end
					if hit then
						return true
					end
				end
				return false
			end
			local away = (V3.new(booth.Position.X, 0, booth.Position.Z) - V3.new(floorSpot.X, 0, floorSpot.Z)).Unit
			local across = V3.new(-away.Z, 0, away.X)
			local centre = floorSpot + V3.new(0, 5, 0)
			local seenFrom = 0
			for _, eye in { centre, centre - away * 0.45 * floorSize.Z, centre + across * 0.45 * floorSize.X, centre - across * 0.45 * floorSize.X } do
				local chest = frame:PointToWorldSpace(V3.new(0, CHEST * U, STAND_Z * U))
				local head = frame:PointToWorldSpace(V3.new(0, HEAD * U, STAND_Z * U))
				if not blocked(eye, chest) and not blocked(eye, head) then
					seenFrom += 1
				end
			end
			assert(seenFrom == 4, key .. ": the DJ's chest and head show from the middle, the back and both sides of the dance floor (" .. seenFrom .. "/4)")
			-- From the middle: the console's top edge clears the wall and its foot does not.
			assert(not blocked(centre, frame:PointToWorldSpace(V3.new(0, DESK_TOP * U, DESK_FRONT * U))), key .. ": the console rises over the wall")
			assert(blocked(centre, frame:PointToWorldSpace(V3.new(0, 1.2 * U, DESK_FRONT * U))), key .. ": ...from behind it, the stage hidden")
			local out = (V3.new(booth.Position.X, 0, booth.Position.Z) - V3.new(floorSpot.X, 0, floorSpot.Z)).Magnitude
			assert(out > 150, key .. ": out past the lobby (" .. math.floor(out) .. " studs from the dance floor)")
		end

		-- The server builds it (World 1), with a stand-in avatar.
		local world1 = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
		local world1Workspace = world1:GetService("Workspace")
		local spawned, delays = {}, {}
		local waits = 0
		local function rig()
			local model = roblox.Instance.new("Model")
			local root = roblox.Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = V3.new(2, 2, 1)
			root.CFrame = roblox.CFrame.new(0, 10, 0)
			root.Parent = model
			for _, limb in {
				{ "Head", V3.new(0, 2.5, 0), V3.new(2, 1, 1) },
				{ "LeftUpperLeg", V3.new(-0.5, -1.2, 0), V3.new(1, 1.6, 1) },
				{ "RightUpperLeg", V3.new(0.5, -1.2, 0), V3.new(1, 1.6, 1) },
				{ "LeftFoot", V3.new(-0.5, -2.8, 0), V3.new(1, 0.4, 1) },
				{ "RightFoot", V3.new(0.5, -2.8, 0), V3.new(1, 0.4, 1) },
			} do
				local part = roblox.Instance.new("Part")
				part.Name = limb[1]
				part.Size = limb[3]
				part.CFrame = roblox.CFrame.new(V3.new(0, 10, 0) + limb[2])
				part.CanCollide = true
				part.Parent = model
			end
			local humanoid = roblox.Instance.new("Humanoid")
			humanoid.Parent = model
			return model
		end
		local asked = {}
		local env = environment(world1, {
			Config = { AdminDisco = AdminDisco, IsNewWorld1Map = true },
			CFrame = CFrameRoblox,
			UDim = roblox.UDim,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			Players = {
				CreateHumanoidModelFromUserId = function(_, userId)
					table.insert(asked, userId)
					return rig()
				end,
				CreateHumanoidModelFromDescription = function()
					return rig()
				end,
				PlayerRemoving = { Connect = function() end },
			},
			Workspace = setmetatable({
				GetServerTimeNow = function()
					return 1234
				end,
			}, { __index = function(_, key)
				local value = world1Workspace[key]
				if type(value) == "function" then
					return function(_, ...)
						return value(world1Workspace, ...)
					end
				end
				return value
			end }),
		})
		env.task = {
			spawn = function(callback)
				table.insert(spawned, callback)
			end,
			delay = function(seconds, callback)
				table.insert(delays, { Seconds = seconds, Callback = callback })
			end,
			wait = function()
				-- The first wait lets the avatar's joints settle; the next is the dance loop.
				waits += 1
				if waits > 1 then
					error("stop dancing")
				end
			end,
		}
		-- Parenting needs the real Workspace, not the stand-in with the server clock.
		local boothChunk = string.gsub(chunkBetween("local function lobbyCenter", "local function startSandstorm"), "booth.Parent = Workspace\n", "booth.Parent = RealWorkspace\n")
		env.RealWorkspace = world1Workspace
		local startDisco, stopDisco = luau.load(boothChunk .. "\nreturn startDisco, stopDisco", { environment = env })()
		startDisco(120, { UserId = 767108248, Name = "GekkoH" })
		local booth = assert(world1Workspace:FindFirstChild("AdminDJBooth"), "The DJ booth goes up with the disco")
		assert(booth.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Persistent and booth:GetAttribute("DJName") == "GekkoH", "Sent to every player, and it knows its DJ")
		local spot = AdminDisco.WorldPlacement.World1.Booth
		local face = ((spot.Face - spot.Position) * V3.new(1, 0, 1)).Unit
		local frame = lookAt(spot.Position, V3.new(spot.Face.X, spot.Position.Y, spot.Face.Z))
		local stage = booth.Stage
		assert(booth:GetAttribute("DJScale") == U, "The booth carries its scale for the clients")
		assert((stage.CFrame.Position - (spot.Position + V3.new(0, 0.6 * U, 0))).Magnitude < 0.05 and stage.CFrame.LookVector:Dot(face) > 0.999, "The stage stands on its spot, facing the dance floor")
		assert(math.abs(stage.Size.X - 22 * U) < 1e-3, "Giant: a " .. math.floor(22 * U) .. "-stud stage")
		local tower = assert(booth:FindFirstChild("StageTower"), "A tower carries the stage down out of sight")
		assert(math.abs((tower.CFrame.Position.Y + tower.Size.Y / 2) - spot.Position.Y) < 0.05, "...right under the stage")
		local counts = { DJNeon = 0, DJBar = 0, DJWoofer = 0, DJSpot = 0 }
		for _, part in booth:GetDescendants() do
			if part:IsA("BasePart") then
				for attribute in counts do
					if part:GetAttribute(attribute) ~= nil then
						counts[attribute] += 1
					end
				end
				local rel = frame:PointToObjectSpace(part.CFrame.Position)
				assert(math.abs(rel.X) <= (HALF_W + 0.5) * U and math.abs(rel.Z) <= (HALF_D + 0.5) * U and rel.Y <= TOP * U and rel.Y >= -TOWER * U, part.Name .. " stays inside the booth")
			end
		end
		assert(counts.DJNeon >= 16 and counts.DJBar == 12 and counts.DJWoofer == 4 and counts.DJSpot == 4, "Neon, twelve equaliser bars, four woofer rings, four spotlights")
		local desk = booth.Desk
		local deskRel = frame:PointToObjectSpace(desk.CFrame.Position)
		assert(math.abs(deskRel.Y + desk.Size.Y / 2 - DESK_TOP * U) < 0.05, "The console's top is at the DJ's waist")
		assert(math.abs(deskRel.Z + desk.Size.Z / 2 - (DESK_FRONT + 1.6) * U) < 0.05 and deskRel.Z < STAND_Z * U, "The console stands in front of the DJ")
		local chest = frame:PointToWorldSpace(V3.new(0, CHEST * U, STAND_Z * U))
		for _, part in booth:GetChildren() do
			if part:GetAttribute("DJSpot") ~= nil then
				local light = part:FindFirstChildOfClass("SpotLight")
				assert(light and part.CFrame.LookVector:Dot((chest - part.CFrame.Position).Unit) > 0.999, "Every spotlight is on the DJ")
				assert(light.Range <= 60 and (chest - part.CFrame.Position).Magnitude <= light.Range, "...and reaches the DJ (Roblox lights stop at 60 studs)")
			end
		end
		for _, bar in booth:GetChildren() do
			if bar:GetAttribute("DJBar") ~= nil then
				local foot = frame:PointToObjectSpace(bar:GetAttribute("DJBarFoot").Position)
				assert(foot.Y >= DESK_TOP * U, "The equaliser bars stand over the console, where they show")
				assert(math.abs(bar:GetAttribute("DJBarMax") - 8.4 * U) < 1e-3, "...as tall as the booth is big")
			end
		end

		-- The avatar arrives, stands behind the console with its hips just under the top,
		-- and wears its sign.
		assert(#spawned == 1, "The avatar loads without holding up the stage")
		table.remove(spawned, 1)()
		assert(waits == 1, "The avatar settles for a frame before it is placed")
		assert(asked[1] == 767108248, "The DJ is the admin who started the party")
		local dj = assert(booth:FindFirstChild("DJ"), "The DJ is on the stage")
		assert(dj.HumanoidRootPart.Anchored, "Fixed in place")
		local hips = -math.huge
		for _, part in dj:GetDescendants() do
			if part:IsA("BasePart") then
				assert(not part.CanCollide and not part.CanTouch, "The DJ bumps nobody")
				if string.find(part.Name, "Leg") or string.find(part.Name, "Foot") then
					local top = part.CFrame.Position.Y + part.Size.Y / 2
					hips = math.max(hips, top)
					assert(top <= spot.Position.Y + DESK_TOP * U + 1e-3, part.Name .. " is hidden behind the console")
				end
			end
		end
		assert(math.abs(hips - (spot.Position.Y + (DESK_TOP - 0.1) * U)) < 0.02, "The hips sit just under the console's top")
		local rootRel = frame:PointToObjectSpace(dj.HumanoidRootPart.CFrame.Position)
		assert(math.abs(rootRel.Z - STAND_Z * U) < 0.02 and math.abs(rootRel.X) < 0.02, "Right behind the console, in the middle")
		assert(dj.HumanoidRootPart.CFrame.LookVector:Dot(face) > 0.999, "Facing the dance floor")
		assert(dj.Head.CFrame.Position.Y > spot.Position.Y + DESK_TOP * U, "The head shows over the console")
		local sign = assert(dj.Head:FindFirstChild("DJSign"), "A sign over the DJ's head")
		assert(sign.Plate.Title.Text == "DJ GekkoH" and sign.Plate.HeadphonesLeft.Text == "🎧" and sign.Plate.HeadphonesRight.Text == "🎧", "🎧 DJ GekkoH 🎧")
		assert(sign.Size.X.Scale == 16 * U and sign.MaxDistance >= 1000, "A giant sign, readable from the whole lobby")
		assert(not sign.Plate.HeadphonesLeft:FindFirstChildOfClass("UIStroke"), "...the headphones on their own, not outlined")
		assert(#spawned == 1, "The dance starts")
		assert(not pcall(table.remove(spawned, 1)), "...and loops until the booth goes")
		has(service, 'track.Looped = true', "The dance loops")
		has(service, '"rbxassetid://507771019"', "Roblox's R15 dances")
		has(service, '"rbxassetid://182435998"', "...and R6 ones")

		-- The clients light it in time.
		local clientChunk = string.gsub(chunkBetweenIn(effects, "local DJ = {", "-- Fireworks (the admin's Fireworks event)"), "holder.Parent = Workspace\n", "holder.Parent = RealWorkspace\n")
		local clock = 0
		local clientEnv = setmetatable({
			Workspace = {
				FindFirstChild = function(_, name)
					return world1Workspace:FindFirstChild(name)
				end,
				GetServerTimeNow = function()
					return clock
				end,
			},
			RealWorkspace = world1Workspace,
			disco = nil,
			os = { clock = function()
				return clock
			end },
			task = { delay = function() end },
			Instance = roblox.Instance,
			Enum = roblox.Enum,
			Vector3 = V3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequence = roblox.NumberSequence,
			NumberRange = roblox.NumberRange,
			typeof = typeof,
		}, { __index = _G })
		local updateDJBooth = luau.load(clientChunk .. "\nreturn updateDJBooth", { environment = clientEnv })()
		local bars = {}
		for _, part in booth:GetChildren() do
			if part:GetAttribute("DJBar") ~= nil then
				table.insert(bars, part)
			end
		end
		updateDJBooth(1 / 60)
		assert(world1Workspace:FindFirstChild("AdminDJConfetti"), "It arrives in a burst of confetti")
		local heights, colours = {}, {}
		for _ = 1, 30 do
			clock += 1 / 30
			updateDJBooth(1 / 30)
			for index, bar in bars do
				heights[index] = heights[index] or {}
				heights[index][string.format("%.2f", bar.Size.Y)] = true
				local foot = bar:GetAttribute("DJBarFoot")
				assert(math.abs((bar.CFrame.Position.Y - bar.Size.Y / 2) - foot.Position.Y) < 0.02, "Each equaliser bar grows up from its foot")
			end
			colours[string.format("%.2f", booth.StageLip.Color.R)] = true
		end
		local moving = 0
		for _, seen in heights do
			local count = 0
			for _ in seen do
				count += 1
			end
			if count > 5 then
				moving += 1
			end
		end
		assert(moving == 12, "Every equaliser bar dances")
		local shades = 0
		for _ in colours do
			shades += 1
		end
		assert(shades > 5, "The neon runs through the colours")

		-- The party ends: the booth fades into confetti, then goes.
		for _, child in world1Workspace:GetChildren() do
			if child.Name == "AdminDJConfetti" then
				child:Destroy()
			end
		end
		stopDisco()
		assert(booth:GetAttribute("Leaving") ~= nil, "Ending the disco sends the DJ off")
		clock += 1 / 30
		updateDJBooth(1 / 30)
		assert(world1Workspace:FindFirstChild("AdminDJConfetti"), "...in a shower of confetti")
		for _ = 1, 60 do
			clock += 1 / 30
			updateDJBooth(1 / 30)
		end
		for _, part in booth:GetDescendants() do
			if part:IsA("BasePart") then
				assert(part.Transparency > 0.99, "...fading out of sight: " .. part.Name)
			end
		end
		local leave = nil
		for _, entry in delays do
			if entry.Seconds == 2.5 then
				leave = entry
			end
		end
		assert(leave, "...and taken down a moment later")
		leave.Callback()
		assert(not world1Workspace:FindFirstChild("AdminDJBooth"), "Gone")

		-- Who the DJ is travels with the event, here and to every server.
		has(service, 'runEvent(payload.name, duration, enabled, { UserId = admin.UserId, Name = byName })', "The panel's Disco names its DJ")
		has(service, 'publish("Event", { name = payload.name, duration = duration, enabled = enabled, byId = admin.UserId, byName = byName }, admin)', "...on every server")
		print("PASS DJ booth: giant, out past each lobby's back wall, console over the wall hiding the DJ's legs, DJ seen from the waist up; lit on the beat, gone in confetti")
	end

	-- 🏃 The admin treadmill: glowing, signed, with the game's aura effects and confetti.
	local dressChunk = string.gsub(chunkBetween("local TREADMILL_AURAS", "local function spawnTreadmill"), "model:GetBoundingBox%(%)", "boxOf(model)")
	local treadmillEnv = environment(place, {
		boxOf = function()
			return roblox.CFrame.new(0, 5, 0), roblox.Vector3.new(20, 4, 40)
		end,
		os = { time = function()
			return 1000
		end },
	})
	local dress = luau.load(dressChunk .. "\nreturn dressAdminTreadmill", { environment = treadmillEnv })()
	local model = place:GetService("ReplicatedStorage").Admin:Clone()
	model:SetAttribute("AdminSpeedGain", 315)
	dress(model, 5, 10)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "AdminTreadmillVFX" then
			assert(part.Material == roblox.Enum.Material.Neon, "Every part glows")
		end
	end
	assert(model:GetAttribute("AdminRainbow") == true and model:GetAttribute("AdminMultiplier") == 5 and model:GetAttribute("AdminExpiresAt") == 1600, "Clients paint it rainbow and count its time down")
	local vfx = assert(model:FindFirstChild("AdminTreadmillVFX"), "The effects part")
	assert(vfx:FindFirstChild("RainbowLight"), "A light that changes colour")
	local emitters = 0
	for _, child in vfx:GetChildren() do
		if child:IsA("ParticleEmitter") then
			emitters += 1
			assert(child.Enabled, "Effects are on")
		end
	end
	assert(emitters >= 8, "The game's own aura effects and confetti (" .. emitters .. " emitters)")
	local sign = assert(vfx:FindFirstChild("AdminTreadmillSign"), "A sign")
	assert(sign.Title.Text == "ADMIN TREADMILL" and sign.Title:FindFirstChild("Rainbow"), "It says ADMIN TREADMILL in rainbow")
	assert(sign.Subtitle.Text == "x315 Speed + x5 Wins - hop on!", "...with its Speed (Hacker + 5%) and the admin's Wins multiplier: " .. sign.Subtitle.Text)
	print("PASS Admin treadmill: glowing rainbow parts, an ADMIN TREADMILL sign, the game's aura effects and confetti")

	-- 📍 Where it stands: the lobby's own spot, upright on the floor, runner facing the way
	-- the spot says, clear of everything around it, and one at a time.
	do
		local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
		local function configBlock(first, last)
			local a = assert(string.find(configSource, first, 1, true), "Config block " .. first)
			local b = assert(string.find(configSource, last, a, true), "Config block end " .. last)
			return string.sub(configSource, a, b - 1)
		end
		local Config = luau.load(
			"local Config = {}\n"
				.. configBlock("Config.SpinWheel = {", "\n}\n") .. "\n}\n"
				.. configBlock("Config.AfkZone = {", "\n}\n") .. "\n}\n"
				.. configBlock("Config.AdminTreadmill = {", "\n}\n") .. "\n}\n"
				.. "return Config",
			{ environment = setmetatable({ Vector3 = roblox.Vector3 }, { __index = _G }) }
		)()
		local V3 = roblox.Vector3
		local function corners(part)
			local half = part.Size / 2
			local list = {}
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						table.insert(list, part.CFrame:PointToWorldSpace(V3.new(half.X * x, half.Y * y, half.Z * z)))
					end
				end
			end
			return list
		end
		local function box(parts)
			local low, high = V3.new(math.huge, math.huge, math.huge), V3.new(-math.huge, -math.huge, -math.huge)
			for _, part in parts do
				for _, corner in corners(part) do
					low = V3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
					high = V3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
				end
			end
			return low, high
		end
		local function partsOf(model)
			local list = {}
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(list, descendant)
				end
			end
			return list
		end
		local placeChunk = chunkBetween("local function treadmillFrame", "-- This lobby's treadmill spot")
		for _, world in { { "World1", PlaceFiles.World1 }, { "World2", PlaceFiles.World2 }, { "World3", PlaceFiles.World3 } } do
			local key, file = world[1], world[2]
			local lobby = roblox.deserializePlace(fs.readFile(file))
			local lobbyWorkspace = lobby:GetService("Workspace")
			local treadmillFrame, placeTreadmill = luau.load(placeChunk .. "\nreturn treadmillFrame, placeTreadmill", { environment = environment(lobby) })()
			local spot = assert(Config.AdminTreadmill.WorldPlacement[key], key .. " has a treadmill spot")
			local face = ((spot.Face - spot.Position) * V3.new(1, 0, 1)).Unit
			local model = lobby:GetService("ReplicatedStorage").Admin:Clone()
			local before = partsOf(model)
			local ups, gaps = {}, {}
			for index, part in before do
				ups[index] = part.CFrame.UpVector.Y
				gaps[index] = (part.CFrame.Position - before[1].CFrame.Position).Magnitude
			end
			local stand = assert(placeTreadmill(model, spot.Position, spot.Position.Y, face), key .. ": the template has a belt")
			local frame = treadmillFrame(model)
			-- Centred in front of the way out to Stage 1 (2026-09-18 pre-launch review): its
			-- runner looks from the spawn out at the track, the lobby floor ends a few studs in
			-- front of it (nothing but the exit ahead), and it sits on the exit's middle line.
			local spawnPoint
			for _, part in lobbyWorkspace:GetDescendants() do
				if part:IsA("SpawnLocation") and part.Enabled then
					spawnPoint = part.CFrame.Position
					break
				end
			end
			local outward = ((spot.Position - spawnPoint) * V3.new(1, 0, 1)).Unit
			assert(frame.Face:Dot(outward) > 0.97, key .. ": its runner looks out of the lobby, away from the spawn (" .. frame.Face:Dot(outward) .. ")")
			local function lobbyFloorAt(point)
				for _, part in lobbyWorkspace:GetDescendants() do
					if part:IsA("BasePart") and part.CanCollide and part ~= lobbyWorkspace.Terrain then
						local local_ = part.CFrame:PointToObjectSpace(point)
						if math.abs(local_.X) <= part.Size.X / 2 and math.abs(local_.Z) <= part.Size.Z / 2 then
							local top = -math.huge
							for _, corner in corners(part) do
								top = math.max(top, corner.Y)
							end
							if math.abs(top - spot.Position.Y) < 0.05 then
								return true
							end
						end
					end
				end
				return false
			end
			local halfLength = 0
			for _, part in before do
				for _, corner in corners(part) do
					halfLength = math.max(halfLength, (corner - V3.new(frame.Centre.X, corner.Y, frame.Centre.Z)):Dot(frame.Face))
				end
			end
			local frontEnd = V3.new(frame.Centre.X, spot.Position.Y, frame.Centre.Z) + frame.Face * halfLength
			local ahead = nil
			for step = 1, 40 do
				if not lobbyFloorAt(frontEnd + frame.Face * step * 0.5) then
					ahead = step * 0.5
					break
				end
			end
			assert(ahead and ahead >= 2 and ahead <= 8, key .. ": the lobby ends " .. tostring(ahead) .. " studs past its front, so it is the last thing before Stage 1")
			if key == "World2" then
				-- Between the two walls that lead onto the parkour.
				local side = V3.new(-frame.Face.Z, 0, frame.Face.X)
				local function wallAt(direction)
					for step = 1, 120 do
						local point = frontEnd + direction * step * 0.5 + V3.new(0, 6, 0)
						for _, part in lobbyWorkspace:GetDescendants() do
							if part:IsA("BasePart") and part.CanCollide and part ~= lobbyWorkspace.Terrain then
								local local_ = part.CFrame:PointToObjectSpace(point + frame.Face * (ahead + 3))
								if math.abs(local_.X) <= part.Size.X / 2 and math.abs(local_.Y) <= part.Size.Y / 2 and math.abs(local_.Z) <= part.Size.Z / 2 then
									return step * 0.5
								end
							end
						end
					end
					return nil
				end
				local left, right = wallAt(-side), wallAt(side)
				assert(left and right and math.abs(left - right) < 1.5, key .. ": in the middle of the opening between the walls (" .. tostring(left) .. " / " .. tostring(right) .. ")")
			else
				-- On the line of the start strip the lobby lays down toward Stage 1.
				local strip = if key == "World1" then lobbyWorkspace.Folder.Union else lobbyWorkspace.Lobby.Union
				local offset = (strip.CFrame.Position - spot.Position) * V3.new(1, 0, 1)
				local across = offset - frame.Face * offset:Dot(frame.Face)
				assert(across.Magnitude < 0.5 and offset:Dot(frame.Face) < 0, key .. ": on the start strip's line, just past it (" .. across.Magnitude .. ")")
			end
			for index, part in before do
				assert(math.abs(part.CFrame.UpVector.Y - ups[index]) < 1e-4, key .. ": turned only around the vertical, nothing tips over")
				assert(math.abs((part.CFrame.Position - before[1].CFrame.Position).Magnitude - gaps[index]) < 1e-3, key .. ": moved whole, in one piece")
			end
			assert(math.abs(frame.Centre.X - spot.Position.X) < 0.01 and math.abs(frame.Centre.Z - spot.Position.Z) < 0.01, key .. ": centred on its spot")
			assert(math.abs(frame.Bottom - spot.Position.Y) < 0.01, key .. ": resting on the floor, not sunk or floating")
			assert(frame.Face:Dot(face) > 0.999, key .. ": its runner faces the way the spot says")
			local low, high = box(before)
			assert(stand.X > low.X and stand.X < high.X and stand.Z > low.Z and stand.Z < high.Z and math.abs(stand.Y - (frame.BeltTop + 3)) < 0.01, key .. ": the stand point is on the belt")

			-- The spot is the lobby floor: solid ground right under it, at its height.
			local floorTop = -math.huge
			for _, part in lobbyWorkspace:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide and part ~= lobbyWorkspace.Terrain then
					local local_ = part.CFrame:PointToObjectSpace(spot.Position)
					if math.abs(local_.X) <= part.Size.X / 2 and math.abs(local_.Z) <= part.Size.Z / 2 then
						local top = -math.huge
						for _, corner in corners(part) do
							top = math.max(top, corner.Y)
						end
						if top <= spot.Position.Y + 3 and top > spot.Position.Y - 20 then
							floorTop = math.max(floorTop, top)
						end
					end
				end
			end
			assert(math.abs(floorTop - spot.Position.Y) < 0.05, key .. ": the spot's height is the floor's (" .. floorTop .. ")")

			-- Nothing of the map inside it.
			local margin = 3
			for _, part in lobbyWorkspace:GetDescendants() do
				if part:IsA("BasePart") and part ~= lobbyWorkspace.Terrain and part.Transparency < 1 then
					local partLow, partHigh = box({ part })
					local overlaps = partLow.X < high.X + margin and partHigh.X > low.X - margin
						and partLow.Z < high.Z + margin and partHigh.Z > low.Z - margin
						and partHigh.Y > spot.Position.Y + 0.3 and partLow.Y < high.Y
					assert(not overlaps, key .. ": " .. part:GetFullName() .. " is in the treadmill's way")
				end
			end
			-- Clear of the spawn, the AFK Zone and the Spin Wheel.
			local function clearOf(centre, radius, label)
				local nearestX = math.clamp(centre.X, low.X, high.X)
				local nearestZ = math.clamp(centre.Z, low.Z, high.Z)
				local distance = (V3.new(centre.X, 0, centre.Z) - V3.new(nearestX, 0, nearestZ)).Magnitude
				assert(distance > radius, key .. ": clear of the " .. label .. " (" .. math.floor(distance) .. " studs)")
			end
			local spawn
			for _, part in lobbyWorkspace:GetDescendants() do
				if part:IsA("SpawnLocation") and part.Enabled then
					spawn = part
					break
				end
			end
			clearOf(spawn.CFrame.Position, 12, "spawn")
			clearOf(Config.SpinWheel.WorldPlacement[key].Position, 12, "Spin Wheel")
		end

		-- spawnTreadmill itself: on the spot wherever the admin is, one at a time, sent to
		-- every player, with the stand point for the GO button.
		local spawnChunk = string.gsub(string.gsub(chunkBetween("local TREADMILL_FOLDER", "-- The GO button on the treadmill's reveal"), "floorAt%(position%)", "position.Y"), "model:GetBoundingBox%(%)", "boxOf(model)")
		local world1 = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
		local spawnEnv = environment(world1, {
			Config = { AdminTreadmill = Config.AdminTreadmill, IsNewWorld1Map = true },
			ReplicatedStorage = world1:GetService("ReplicatedStorage"),
			boxOf = function()
				return roblox.CFrame.new(0, 5, 0), roblox.Vector3.new(20, 4, 40)
			end,
			os = { time = function()
				return 1000
			end },
			lobbyCenter = function()
				error("the World 1 spot is configured")
			end,
		})
		local spawnTreadmill = luau.load(spawnChunk .. "\nreturn spawnTreadmill", { environment = spawnEnv })()
		local admin = { UserId = 767108248 }
		assert(spawnTreadmill(admin, 5, 10))
		assert(spawnTreadmill(admin, 8, 5))
		local folder = world1:GetService("Workspace"):FindFirstChild("AdminSpawnedTreadmills")
		assert(folder and #folder:GetChildren() == 1, "A new admin treadmill replaces the old one")
		local spawned = folder:GetChildren()[1]
		assert(spawned:GetAttribute("AdminMultiplier") == 8, "...with the newest multiplier")
		assert(typeof(spawned:GetAttribute("AdminTreadmillStand")) == "Vector3" and typeof(spawned:GetAttribute("AdminTreadmillFace")) == "Vector3", "It carries where to stand, for the GO button")
		assert(spawned.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Persistent, "Every player gets it, however far away")
		local spot = Config.AdminTreadmill.WorldPlacement.World1.Position
		assert((V3.new(spawned:GetAttribute("AdminTreadmillStand").X, 0, spawned:GetAttribute("AdminTreadmillStand").Z) - V3.new(spot.X, 0, spot.Z)).Magnitude < 25, "On World 1's spot, not where the admin stands")
		for _, descendant in spawned:GetDescendants() do
			assert(not descendant:IsA("LuaSourceContainer"), "No scripts ride along")
		end
		assert(not string.find(service, "Stand somewhere first", 1, true) and not string.find(service, "root.CFrame.LookVector * Vector3.new(1, 0, 1)", 1, true), "The admin's own position no longer decides where it goes")
		assert(spawned:GetAttribute("TreadmillTrainingSourceName") == "Admin3000" and spawned:GetAttribute("AdminSpeedGain") == 315, "It trains with the Admin3000 profile (the Hacker treadmill's plus 5%)")
		print("PASS Admin treadmill spot: centred in front of each lobby's way out to Stage 1, upright on the floor, clear of the map, the spawn and the wheel, one at a time")

		-- 💰 What it pays: exactly 5% over the Hacker treadmill, in every world; the admin's
		-- multiplier only raises the Wins.
		local profiles = luau.load(
			"local Config = { IsWorld2Place = false, IsWorld3Place = false }\n"
				.. configBlock("Config.World2TreadmillProfiles = {", "\nConfig.NewWorld1TreadmillProfiles") .. "\n"
				.. configBlock("Config.NewWorld1TreadmillProfiles = {", "\n}\n") .. "\n}\n"
				.. "return Config",
			{ environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }) }
		)()
		for _, name in { "World2TreadmillProfiles", "World3TreadmillProfiles", "NewWorld1TreadmillProfiles" } do
			local list = profiles[name]
			assert(list.Admin3000.BaseGain == list.Hacker.BaseGain * 1.05 and list.Admin3000.BaseGain == 315, name .. ": Admin3000 pays the Hacker's 300 plus 5%")
			assert(list.Admin3000.DisplayText == "x315 Speed\n(+5% Hacker)", name .. ": ...and says so")
			assert((tonumber(list.Admin3000.GamePassId) or 0) == 0 and list.Admin3000.SpawnedAtRuntime, name .. ": free for everyone, spawned by the panel")
		end
		local training = fs.readFile("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau")
		local pay = string.sub(training, assert(string.find(training, "local function addSpeed", 1, true)), assert(string.find(training, "task.wait(1)\nregisterTreadmills()", 1, true)))
		assert(not string.find(pay, "AdminTreadmillSpeedMult", 1, true) and not string.find(pay, "baseGain = baseGain *", 1, true), "Its Speed is never multiplied by the admin's number")
		assert(string.find(pay, "addWins(player, winBase * winMult)", 1, true), "...its Wins are")
		assert(not string.find(service, "Treadmill5_insanespeed", 1, true), "It no longer trains as the 50,000,000 insane-speed treadmill")
		print("PASS Admin treadmill pay: x315 Speed (Hacker + 5%) in every world, the admin's multiplier on Wins only")
	end

	-- 🎟️ Gamepasses: the saved perk first, then the flags the game reads.
	local passChunk = chunkBetween("local PASSES = {", "----------------------------------------------------------------------\n-- Cross-server")
	local commits = {}
	local refreshed = 0
	local passEnv = setmetatable({
		commit = function(_, commands)
			table.insert(commits, commands)
			return true
		end,
		refreshStats = function()
			refreshed += 1
		end,
		Config = { VipSpeedGainMultiplier = 2, VipWinsMultiplier = 2 },
		-- The 2x Speed raise reads the saved multiplier (2026-09-21); no profile here.
		DataService = { GetHandle = function() return nil end },
		GiftedPasses = { Has = function() return false end },
		_G = {},
	}, { __index = _G })
	local setPass = luau.load(passChunk .. "\nreturn setPass", { environment = passEnv })()
	local attributes = {}
	local victim = { SetAttribute = function(_, key, value)
		attributes[key] = value
	end, GetAttribute = function(_, key)
		return attributes[key]
	end }
	assert(setPass(victim, "All", true) == true, "Giving every pass")
	local kinds = {}
	for _, command in commits[1] do
		kinds[command.kind .. ":" .. tostring(command.upgradeId or command.skinId or command.key or command.equipped)] = true
	end
	for _, expected in { "GrantUpgrade:VIP", "GrantUpgrade:Flight", "GrantUpgrade:TwoXSpeed", "GrantUpgrade:TwoXVictory", "GrantUpgrade:InfiniteRevives", "GrantSkin:DarkZonic", "SetAbilityEquipped:true", "SetPersistent:PermanentBaseSpeedMultiplier" } do
		assert(kinds[expected], "Saved: " .. expected)
	end
	assert(attributes.VIPGamepassOwned == true and attributes.GamepassSpeedGainMultiplier == 2 and attributes.TwoXVictoryOwned == true and attributes.InfiniteRevivesOwned == true and attributes.DarkZonicOwned == true, "The game sees every pass at once")
	assert(attributes.StaminaRegen2xOwned == true, "All includes the 2x Stamina Regen session flag (Update 4)")
	setPass(victim, "Flight", false)
	assert(commits[2][1].kind == "RemoveUpgrade" and commits[2][1].upgradeId == "Flight" and commits[2][2].equipped == false, "Taking Flight away")
	assert(refreshed == 2, "Stats refresh after each change")
	has(service, 'pcall(_G.SpeedsterPerformRebirth, victim, true)', "Force Rebirth uses the rebirth system")
	has(service, 'pcall(_G.SpeedsterRedeemCode, victim, code, true, byName)', "Codes use the codes system")
	has(service, 'pcall(_G.SpeedsterAdminWorldTravel, admin, world)', "Travel uses free admin world travel")
	print("PASS Stats & Passes: gamepasses saved and applied, rebirths, codes and travel through the game's own systems")

	-- 📢 Announcement themes: the ones the panel offers are the ones the banner draws.
	local messages = fs.readFile("src/common/StarterGui/Messages/MessageHandler.client.luau")
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	for _, theme in { "Gold", "Rainbow", "Alert", "Ice", "Party" } do
		has(service, theme .. " = true", "The service accepts the " .. theme .. " theme")
		has(messages, theme .. " = { Top", "The banner draws the " .. theme .. " theme")
		has(controller, '{ "' .. theme .. '", ', "The panel offers the " .. theme .. " theme")
	end
	has(messages, "MaxVisibleGraphemes", "The message types itself out")
	has(messages, 'stage.ZIndexBehavior = Enum.ZIndexBehavior.Sibling', "The banner draws sibling by sibling")
	print("PASS Announcements: five banner themes, offered, accepted and drawn, typed out one banner at a time")

	-- The banner laid out on real screens: the shine stays inside the card, the words sit in
	-- their own column clear of the badge and the time bar, and the emojis stand alone.
	do
		local function between(first, last)
			local a = assert(string.find(messages, first, 1, true), "banner chunk " .. first)
			local b = assert(string.find(messages, last, a, true), "banner chunk end " .. last)
			return string.sub(messages, a, b - 1)
		end
		local clock = 0
		local renders = {}
		local playerGui = roblox.Instance.new("Folder")
		local env = setmetatable({
			Instance = roblox.Instance,
			Enum = roblox.Enum,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Vector2 = roblox.Vector2,
			player = { WaitForChild = function()
				return playerGui
			end },
			sound = {},
			Players = { GetUserThumbnailAsync = function()
				return "rbxthumb://avatar"
			end },
			TweenInfo = { new = function()
				return {}
			end },
			TweenService = { Create = function(_, object, _, goal)
				return {
					Play = function()
						for key, value in goal do
							object[key] = value
						end
					end,
					Completed = { Wait = function() end },
				}
			end },
			RunService = { RenderStepped = { Connect = function(_, callback)
				table.insert(renders, callback)
				return { Disconnect = function() end }
			end } },
			os = { clock = function()
				return clock
			end },
		}, { __index = _G })
		local chunk = between("local stage = Instance.new", "-- One banner at a time")
		local stage, displayAnnouncement, THEMES
		env.task = { spawn = function() end }
		stage, displayAnnouncement, THEMES = luau.load(chunk .. "\nreturn stage, displayAnnouncement, THEMES", { environment = env })()

		local screen
		local function rect(object)
			if object == stage then
				return { X = 0, Y = 0, W = screen.X, H = screen.Y }
			end
			local parent = rect(object.Parent)
			local w = parent.W * object.Size.X.Scale + object.Size.X.Offset
			local h = parent.H * object.Size.Y.Scale + object.Size.Y.Offset
			local limit = object:FindFirstChildOfClass("UISizeConstraint")
			if limit then
				w = math.clamp(w, limit.MinSize.X, limit.MaxSize.X)
				h = math.clamp(h, limit.MinSize.Y, limit.MaxSize.Y)
			end
			return {
				X = parent.X + parent.W * object.Position.X.Scale + object.Position.X.Offset - w * object.AnchorPoint.X,
				Y = parent.Y + parent.H * object.Position.Y.Scale + object.Position.Y.Offset - h * object.AnchorPoint.Y,
				W = w,
				H = h,
			}
		end
		local function inside(inner, outer, label)
			assert(inner.X >= outer.X - 0.01 and inner.Y >= outer.Y - 0.01 and inner.X + inner.W <= outer.X + outer.W + 0.01 and inner.Y + inner.H <= outer.Y + outer.H + 0.01, label)
		end
		local function apart(a, b, label)
			assert(a.X + a.W <= b.X + 0.01 or b.X + b.W <= a.X + 0.01 or a.Y + a.H <= b.Y + 0.01 or b.Y + b.H <= a.Y + 0.01, label)
		end

		for _, size in { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(1280, 720), roblox.Vector2.new(700, 390) } do
			screen = size
			for themeName, theme in THEMES do
				for _, senderId in { 767108248, 0 } do
					local where = themeName .. " on " .. size.X .. "x" .. size.Y .. (if senderId > 0 then " with an avatar" else " without one")
					table.clear(renders)
					clock = 0
					env.task.wait = function()
						local card = assert(stage:FindFirstChild("Announcement"), "The card")
						local cardRect = rect(card)
						inside(cardRect, rect(stage), where .. ": the card fits the screen")
						local shine = card:FindFirstChild("Shine")
						local band = shine:FindFirstChildOfClass("UIGradient")
						assert(shine.Size == roblox.UDim2.fromScale(1, 1) and shine.Position == roblox.UDim2.new(0, 0, 0, 0) and shine.Rotation == 0, where .. ": the shine is the card's own shape")
						assert(shine:FindFirstChildOfClass("UICorner").CornerRadius == card:FindFirstChildOfClass("UICorner").CornerRadius, where .. ": ...rounded like the card")
						local offsets = {}
						for step = 0, 12 do
							clock = step * 0.25
							for _, render in renders do
								render(0.25)
							end
							inside(rect(shine), cardRect, where .. ": the shine never leaves the card")
							offsets[band.Offset.X] = true
						end
						local distinct = 0
						for _ in offsets do
							distinct += 1
						end
						assert(distinct >= 6, where .. ": the shine sweeps across")
						local badge = card:FindFirstChild("Badge")
						local body = card:FindFirstChild("Body")
						local header = body:FindFirstChild("Header")
						local title = header:FindFirstChild("Title")
						local icon = header:FindFirstChild("ThemeIcon")
						local message = body:FindFirstChild("Message")
						local timeBar = card:FindFirstChild("TimeBar")
						local megaphone = badge:FindFirstChild("Megaphone")
						for _, part in { badge, body, title, icon, message, timeBar, megaphone } do
							inside(rect(part), cardRect, where .. ": " .. part.Name .. " is inside the card")
						end
						apart(rect(body), rect(badge), where .. ": the words are clear of the badge")
						apart(rect(megaphone), rect(body), where .. ": the megaphone is clear of the words")
						apart(rect(title), rect(message), where .. ": the title and the message do not overlap")
						apart(rect(icon), rect(title), where .. ": the theme icon sits beside the title")
						apart(rect(message), rect(timeBar), where .. ": the message is clear of the time bar")
						assert(rect(body).W >= 250, where .. ": the message has room to read")
						-- A slim ticker under the top bar (2026-09-18, Sung: announcements were
						-- far too big and covered the run).
						assert(cardRect.H <= 60 and cardRect.W <= 720 and cardRect.W <= 0.62 * screen.X, where .. ": a slim ticker, not a big banner")
						assert(cardRect.Y >= 36, where .. ": under Roblox's top bar")
						assert(not stage:FindFirstChild("Flash"), where .. ": no flash over the whole screen")
						assert(not string.find(title.Text, "[\240-\244]"), where .. ": no emoji inside the outlined title")
						for _, holder in { icon, megaphone } do
							local glyph = holder:FindFirstChild("Icon")
							assert(glyph and glyph.TextScaled == false and glyph.TextXAlignment == roblox.Enum.TextXAlignment.Center and glyph.TextYAlignment == roblox.Enum.TextYAlignment.Center, where .. ": the " .. holder.Name .. " emoji is centred at a fixed size")
							assert(not glyph:FindFirstChildOfClass("UIStroke"), where .. ": the " .. holder.Name .. " emoji is not outlined")
						end
						assert(icon:FindFirstChild("Icon").Text == theme.Icon and megaphone:FindFirstChild("Icon").Text == "📢", where .. ": the right emojis")
						if senderId > 0 then
							local chip, face = rect(megaphone), rect(badge)
							assert(math.abs((chip.X + chip.W / 2) - (face.X + face.W - 6)) < 0.01 and math.abs((chip.Y + chip.H / 2) - (face.Y + face.H - 6)) < 0.01, where .. ": the megaphone sticker sits on the badge's corner")
						else
							inside(rect(megaphone), rect(badge), where .. ": the megaphone fills the badge")
						end
					end
					displayAnnouncement({ Message = "Double wins for everyone for the next 10 minutes!", SenderName = "Aoshy", SenderId = senderId, Theme = themeName, Duration = 8 })
					for _, child in stage:GetChildren() do
						child:Destroy()
					end
				end
			end
		end
		print("PASS Announcement layout: the shine stays inside the card, the words clear of the badge and bar, emojis centred on their own")
	end

	-- The pictures every client draws for them.
	local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	for _, needle in {
		'Texture = "rbxassetid://8163218169"',
		"Enum.ParticleFlipbookLayout.Grid4x4",
		'Workspace:GetAttribute("AdminSnowUntil")',
		"snow.Atmosphere.Density = lerp(original.Density, SNOW.Atmosphere.Density, t)",
		'Workspace:GetAttribute("AdminDiscoFloor")',
		'Workspace:FindFirstChild("AdminSpawnedTreadmills")',
		'model:GetAttribute("AdminRainbow") == true',
	} do
		has(effects, needle, "Client effect: " .. needle)
	end
	-- The flakes reach the floor: the sheet sits over the ground a ray finds, every flake
	-- lives for the whole fall, and a running player's snow is born ahead of them.
	do
		local function between(first, last)
			local a = assert(string.find(effects, first, 1, true), "effects chunk " .. first)
			local b = assert(string.find(effects, last, a, true), "effects chunk end " .. last)
			return string.sub(effects, a, b - 1)
		end
		local hits = {}
		local invisibleRoof = { Transparency = 1, CanCollide = false, IsA = function(_, class) return class == "BasePart" end }
		local floor = { Transparency = 0, CanCollide = true, IsA = function(_, class) return class == "BasePart" end }
		local env = setmetatable({
			Workspace = {
				CurrentCamera = {},
				Raycast = function(_, origin, direction, params)
					table.insert(hits, #params.FilterDescendantsInstances)
					local planned = hits.Plan and table.remove(hits.Plan, 1)
					if planned == "roof" then
						return { Instance = invisibleRoof, Position = roblox.Vector3.new(origin.X, origin.Y + 5, origin.Z) }
					elseif planned == "floor" then
						return { Instance = floor, Position = roblox.Vector3.new(origin.X, 0, origin.Z) }
					end
					return nil
				end,
			},
			Players = { GetPlayers = function() return {} end },
			RaycastParams = { new = function() return {} end },
			Enum = roblox.Enum,
			Vector3 = roblox.Vector3,
			Color3 = roblox.Color3,
		}, { __index = _G })
		local chunk = between("local SNOW = {", "local snowWeight") .. between("local function groundBelow", "local function removeSnow")
		local groundBelow, snowPlacement, SNOW = luau.load(chunk .. "\nreturn groundBelow, snowPlacement, SNOW", { environment = env })()
		local slowest = SNOW.Speed * 0.8 * math.cos(math.rad(SNOW.Spread))
		hits.Plan = { "roof", "floor" }
		assert(groundBelow(roblox.Vector3.new(0, 30, 0)) == 0, "The ground ray looks past see-through roofs and zones to the floor")
		hits.Plan = {}
		assert(groundBelow(roblox.Vector3.new(0, 30, 0)) == nil, "No ground under the camera is no ground")
		for _, case in {
			{ Camera = 12, Ground = 0 },
			{ Camera = 40, Ground = 0 },
			{ Camera = 95, Ground = 0 },
			{ Camera = 30, Ground = nil },
			{ Camera = -300, Ground = -320 },
		} do
			local position = roblox.Vector3.new(10, case.Camera, -5)
			local sheet, lifetime = snowPlacement(position, roblox.Vector3.zero, case.Ground)
			assert(sheet.Y >= case.Camera + SNOW.AboveCamera, "The flakes are born over the camera")
			local floorY = case.Ground or (case.Camera - SNOW.FallbackFall + SNOW.AboveCamera)
			assert(lifetime * slowest >= sheet.Y - floorY, "Flakes over a camera at " .. case.Camera .. " live long enough to reach the ground")
			assert(sheet.X == 10 and sheet.Z == -5, "Standing still, the snow is right over the camera")
		end
		local running = snowPlacement(roblox.Vector3.new(0, 12, 0), roblox.Vector3.new(80, 0, 0), 0)
		assert(running.X > 0 and running.X <= SNOW.MaxLead and running.Z == 0, "A running player's snow is born ahead of them, not left behind")
		has(effects, "snow.Emitter.Lifetime = NumberRange.new(lifetime, lifetime * 1.1)", "The flakes' lifetime follows the fall")
		has(effects, "snow.GroundY = groundBelow(position)", "The ground is found while it snows")
		assert(not string.find(effects, "SNOW.CeilingHeight", 1, true), "No fixed sheet height over the camera")
	end
	-- The disco's pieces: where the lights hang, the mirror ball's tiles, the spotlights'
	-- reach, the night falling the short way round the clock, and the map's own light back
	-- exactly once snow and disco are both over.
	do
		local function between(first, last)
			local a = assert(string.find(effects, first, 1, true), "effects chunk " .. first)
			local b = assert(string.find(effects, last, a, true), "effects chunk end " .. last)
			return string.sub(effects, a, b - 1)
		end
		local V3 = roblox.Vector3
		local env = setmetatable({ Vector3 = V3, Color3 = roblox.Color3 }, { __index = _G })
		local discoAnchor, DISCO, ballTiles, spotDirection = luau.load(
			between("local DISCO = {", "local MIRROR") .. between("local function discoAnchor", "local function invisiblePart") .. "\nreturn discoAnchor, DISCO, ballTiles, spotDirection",
			{ environment = env }
		)()
		local center = V3.new(290, 37501.69, -1755)
		local rig, floorY, near = discoAnchor(V3.new(300, 37480, -1760), center, 37467.69, V3.new(290, 37470, -1770), 37466)
		assert(near and floorY == 37467.69 and rig == center, "In the lobby the spotlights hang from the ball, over the dance floor")
		rig, floorY, near = discoAnchor(V3.new(5000, 120, 900), center, 37467.69, V3.new(4990, 104, 910), 100)
		assert(not near and floorY == 100 and rig == V3.new(4990, 100 + DISCO.RigHeight, 910), "Out on the map they hover over the player")
		rig, floorY = discoAnchor(V3.new(5000, 120, 900), center, 37467.69, V3.new(4990, 104, 910), nil)
		assert(floorY == 100 and rig.Y == 130, "With no ground found, the floor is at the player's feet")

		-- The mirror ball: tiles all over it, evenly, a third of them mirror.
		local tiles = ballTiles(DISCO.BallRadius, DISCO.TileSize)
		assert(#tiles >= 150 and #tiles <= 280, "A ball of tiles, not too few and not too many parts (" .. #tiles .. ")")
		local lowest, highest, mirrors = 0, 0, 0
		for index, tile in tiles do
			assert(math.abs(tile.Direction.Magnitude - 1) < 1e-4, "Every tile faces straight out")
			lowest = math.min(lowest, tile.Direction.Y)
			highest = math.max(highest, tile.Direction.Y)
			if tile.Mirror then
				mirrors += 1
			end
			for other = index + 1, #tiles do
				local gap = (tile.Direction - tiles[other].Direction).Magnitude * DISCO.BallRadius
				assert(gap > DISCO.TileSize * 0.6, "No two tiles on top of each other")
			end
		end
		assert(lowest < -0.95 and highest > 0.95, "From pole to pole")
		assert(math.abs(mirrors / #tiles - 1 / 3) < 0.08, "A third mirror, the rest neon colour")

		-- Every spotlight points down and reaches the floor from the ball's height.
		for index = 1, DISCO.Spots do
			for _, now in { 0, 1.3, 2.9, 7.7 } do
				local direction, pitch = spotDirection(index, now)
				assert(direction.Y < -0.4 and math.abs(direction.Magnitude - 1) < 1e-4, "Spotlight " .. index .. " points down at the floor")
				assert(AdminDisco.BallHeight / math.sin(pitch) - DISCO.BallRadius <= 60, "Spotlight " .. index .. " reaches the floor (a light's range tops out at 60)")
			end
		end
		assert(DISCO.RigHeight / math.sin(math.rad(DISCO.SpotPitches[1] - 6)) <= 60, "...and from over a player's head")

		-- The disco's clock: smooth frame to frame even when the server's clock jitters, and in
		-- step with it.
		local rhythm = between("local function discoClock", "local function discoActive")
		local discoClock, BEAT, newBeat, stepBeat = luau.load(rhythm .. "\nreturn discoClock, BEAT, newBeat, stepBeat", { environment = env })()
		local clockNow, truth = nil, 1000
		for frame = 1, 600 do
			truth += 1 / 60
			local jitter = math.sin(frame * 12.9898) * 0.04
			local before = clockNow
			clockNow = discoClock(clockNow, truth + jitter, 1 / 60)
			if before then
				local step = clockNow - before
				assert(step > (1 / 60) * 0.9 and step < (1 / 60) * 1.1, "The disco's clock never jumps or stutters")
			end
		end
		assert(math.abs(clockNow - truth) < 0.06, "...and keeps in step with the server")
		assert(discoClock(clockNow, truth + 30, 1 / 60) == truth + 30, "A long hitch is caught up at once")

		-- The beat: kicks in a song become beats at its tempo; a held note is not a string of
		-- beats; with no song the beat keeps the last tempo.
		local function listen(beat, from, seconds, loudnessAt)
			local hits = {}
			for frame = 1, math.floor(seconds * 60) do
				local now = from + frame / 60
				if stepBeat(beat, 1 / 60, now, loudnessAt(now)) then
					table.insert(hits, now)
				end
			end
			return hits
		end
		local beat = newBeat()
		local hits = listen(beat, 0, 10, function(now)
			return 60 + 400 * math.exp(-((now % 0.5) / 0.04))
		end)
		assert(#hits >= 19 and #hits <= 21, "A 120 BPM song: a beat on every kick (" .. #hits .. " in 10 s)")
		for index = 2, #hits do
			assert(math.abs((hits[index] - hits[index - 1]) - 0.5) < 0.05, "...evenly, on the kicks")
		end
		assert(math.abs(beat.Period - 0.5) < 0.03, "...learning its tempo")
		local pulseAfter = beat.Pulse
		listen(beat, 10, 0.3, function()
			return 60
		end)
		assert(beat.Pulse < 0.2 and pulseAfter > beat.Pulse, "A beat's flare fades quickly")
		local held = listen(newBeat(), 0, 1.5, function(now)
			return if now < 0.1 then 20 else 500
		end)
		assert(#held <= 1, "A long loud note is one beat, not many")
		local quiet = listen(beat, 10.3, 4, function()
			return nil
		end)
		assert(#quiet >= 3 and #quiet <= 6, "With the music off, the beat keeps going (" .. #quiet .. ")")
		for index = 2, #quiet do
			assert(math.abs((quiet[index] - quiet[index - 1]) - beat.Period) < 0.03, "...at the tempo it last heard")
		end
		local faster = newBeat()
		listen(faster, 0, 12, function(now)
			return 60 + 400 * math.exp(-((now % 0.4) / 0.04))
		end)
		assert(math.abs(faster.Period - 0.4) < 0.03, "A faster song, a faster beat")

		local lighting = { Brightness = 3, OutdoorAmbient = roblox.Color3.fromRGB(170, 174, 181), Ambient = roblox.Color3.fromRGB(132, 134, 142), ClockTime = 14.15 }
		local discoColors = { Ambient = roblox.Color3.fromRGB(80, 20, 120), OutdoorAmbient = roblox.Color3.fromRGB(20, 60, 120) }
		local lightEnv = setmetatable({ Lighting = lighting, Color3 = roblox.Color3, DISCO = DISCO, discoColors = discoColors, SNOW = { Brightness = 1.4, OutdoorAmbient = roblox.Color3.fromRGB(150, 162, 180) } }, { __index = _G })
		-- tacosWeight: blendLighting also blends the Raining Tacos sky since 2026-09-24.
		local lightChunk = "local snowWeight, discoWeight, tacosWeight = 0, 0, 0\nlocal function lerp(a, b, t) return a + (b - a) * t end\n"
			.. between("local lightingBase = nil", "-- Admin treadmills")
			.. "\nreturn blendLighting, clockToward, function(s, d) snowWeight, discoWeight = s, d end"
		local blendLighting, clockToward, setWeights = luau.load(lightChunk, { environment = lightEnv })()
		assert(math.abs(clockToward(14.15, 0, 0.5) - 19.075) < 1e-6, "Afternoon runs forward through sunset to midnight")
		assert(math.abs(clockToward(2, 0, 0.5) - 1) < 1e-6 and math.abs(clockToward(22, 0, 1)) < 1e-6, "...and the short way from any hour")
		setWeights(0, 1)
		blendLighting()
		assert(math.min(lighting.ClockTime, 24 - lighting.ClockTime) < 1e-6 and math.abs(lighting.Brightness - DISCO.Brightness) < 1e-6 and lighting.Ambient == discoColors.Ambient, "The disco's night, in the disco's drifting colour")
		discoColors.Ambient = roblox.Color3.fromRGB(20, 120, 80)
		blendLighting()
		assert(lighting.Ambient == discoColors.Ambient, "...following the colour as it drifts")
		setWeights(1, 1)
		blendLighting()
		assert(lighting.OutdoorAmbient == discoColors.OutdoorAmbient, "Disco over snow: one light, no fighting")
		setWeights(1, 0)
		blendLighting()
		assert(math.abs(lighting.ClockTime - 14.15) < 1e-6 and math.abs(lighting.Brightness - 1.4) < 1e-6, "The disco ends while it snows: day again, still snowy")
		setWeights(0, 0)
		blendLighting()
		assert(lighting.Brightness == 3 and lighting.ClockTime == 14.15 and lighting.Ambient == roblox.Color3.fromRGB(132, 134, 142) and lighting.OutdoorAmbient == roblox.Color3.fromRGB(170, 174, 181), "Both over: the map's own lighting, exactly")
		lighting.Brightness = 2.5 -- the map changed its light between events
		setWeights(0, 0.5)
		blendLighting()
		setWeights(0, 0)
		blendLighting()
		assert(lighting.Brightness == 2.5, "The next event starts from the map's light as it is then")
		has(effects, 'typeof(Workspace:GetAttribute("AdminDiscoCenter")) == "Vector3"', "The disco follows the Workspace attributes")
		has(effects, "disco.Angle = (disco.Angle + math.rad(DISCO.SpinDegrees) * dt) % (math.pi * 2)", "The ball turns a little more every frame while the party is on")
		has(effects, "Workspace:BulkMoveTo(ball.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)", "...moving all its pieces in one go")
		has(effects, "\tupdateDisco(dt)\n\tupdateDance(dt)\n\tupdateDJBooth(dt)\n\tblendLighting()\n", "The dance, the DJ booth and the light follow the disco every frame")
	end

	-- The disco frame by frame with real instances: the ball comes down and turns smoothly,
	-- every beam runs from the ball's surface to its dot on the floor, the colours drift
	-- gently, the lights follow the player away from the lobby, and it all goes away cleanly.
	do
		local function between(first, last)
			local a = assert(string.find(effects, first, 1, true), "effects chunk " .. first)
			local b = assert(string.find(effects, last, a, true), "effects chunk end " .. last)
			return string.sub(effects, a, b - 1)
		end
		-- Lune's CFrame.lookAt only gets some directions right; Roblox's gets all of them. The
		-- code under test gets a lookAt built the way Roblox's works.
		local function lookAt(at, target)
			local look = (target - at).Unit
			local up = roblox.Vector3.new(0, 1, 0)
			if math.abs(look:Dot(up)) > 0.9999 then
				up = roblox.Vector3.new(0, 0, 1)
			end
			local right = look:Cross(up).Unit
			return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
		end
		local V3 = roblox.Vector3
		-- Positions this high up (y 37500) are only kept to a few thousandths of a stud.
		local POSITION_TOLERANCE = 0.02
		local DISCO_RADIUS_CHECK = assert(tonumber(string.match(effects, "	BallRadius = (%d+),")), "the ball's radius")
		local DISCO_TILE_THICKNESS = assert(tonumber(string.match(effects, "	TileThickness = ([%d.]+),")), "the tiles' thickness")
		-- A tile's middle is half its thickness under the ball's surface: its outer face is
		-- the surface and its inner half is sunk into the core.
		local TILE_CENTRE_RADIUS = DISCO_RADIUS_CHECK - DISCO_TILE_THICKNESS / 2
		-- One solid ball (2026-09-18 pre-launch review: the tiles read as panels coming loose):
		-- the core reaches past every tile's inner face and stops short of its outer face, and
		-- each ring's tiles close up edge to edge.
		local function checkSolidBall(root, parts, tiles, radius, thickness, label)
			local core
			for _, part in parts do
				if part.Name == "Core" then
					core = part
				end
			end
			assert(core and core.Shape == roblox.Enum.PartType.Ball, label .. ": a round core")
			assert((core.CFrame.Position - root.CFrame.Position).Magnitude < POSITION_TOLERANCE, label .. ": ...in the middle")
			local coreRadius = core.Size.X / 2
			assert(coreRadius > radius - thickness + 0.01 and coreRadius < radius - 0.01, label .. ": the tiles are set into the core, no gap under them (core " .. coreRadius .. ")")
			assert(core.Reflectance > 0.3 and core.Material == roblox.Enum.Material.SmoothPlastic, label .. ": the core is silver too, so what shows between tiles is mirror")
			local rings = {}
			for _, tile in tiles do
				local offset = tile.Part.CFrame.Position - root.CFrame.Position
				assert(math.abs(offset.Magnitude - (radius - thickness / 2)) < POSITION_TOLERANCE, label .. ": each tile sits in the ball's surface")
				assert(tile.Part.CFrame.LookVector:Dot(offset.Unit) > 0.999, label .. ": ...facing out")
				assert(math.abs(tile.Part.Size.Z - thickness) < 1e-4, label .. ": ...its thickness along the radius")
				local key = string.format("%.1f", tile.Latitude)
				rings[key] = rings[key] or { Count = 0, Width = tile.Part.Size.X, Latitude = tile.Latitude }
				rings[key].Count += 1
			end
			for _, ring in rings do
				local circumference = 2 * math.pi * radius * math.cos(ring.Latitude)
				local cover = ring.Count * ring.Width / circumference
				assert(cover > 0.9 and cover < 1, label .. ": a ring's tiles close up edge to edge (" .. cover .. " of it)")
			end
		end
		local floor = V3.new(290.28, 37467.69, -1755.14)
		local center = floor + V3.new(0, AdminDisco.BallHeight, 0)
		local attributes = { AdminDiscoUntil = 100000, AdminDiscoCenter = center, AdminDiscoFloor = floor, AdminDiscoFloorSize = V3.new(112, 0, 140) }
		local camera = roblox.Instance.new("Camera")
		local lighting = roblox.Instance.new("Folder")
		local world = roblox.Instance.new("Folder")
		local clock, serverNow = 0, 5000
		local who = {}
		local playerObject = { GetAttribute = function() end }
		local testPlayers = {} -- Players:GetPlayers() (the followers' players)
		local song = nil -- the admin's track, when one is playing
		local env = setmetatable({
			Workspace = {
				CurrentCamera = camera,
				GetAttribute = function(_, name)
					return attributes[name]
				end,
				GetServerTimeNow = function()
					return serverNow
				end,
				FindFirstChild = function(_, name)
					return if name == "AdminMusic" then song else nil
				end,
			},
			SoundService = { FindFirstChild = function() end },
			WorkspaceFolder = world,
			Lighting = lighting,
			character = function()
				return who.humanoid, who.root
			end,
			player = playerObject,
			Players = { GetPlayers = function()
				return testPlayers
			end },
			groundBelow = function(position)
				return position.Y - 20
			end,
			os = { clock = function()
				return clock
			end },
			UDim2 = roblox.UDim2,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			Instance = roblox.Instance,
			Enum = roblox.Enum,
			Vector3 = V3,
			Vector2 = roblox.Vector2,
			CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame }),
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			NumberRange = roblox.NumberRange,
		}, { __index = _G })
		local chunk = string.gsub(between("local DISCO = {", "-- Fireworks (the admin's Fireworks event)"), "folder.Parent = Workspace\n", "folder.Parent = WorkspaceFolder\n")
		local updateDisco, state, updateDance, floorColour, floorShowsAt = luau.load(chunk .. "\nreturn updateDisco, function() return disco, discoWeight, discoColors end, updateDance, floorColour, floorShowsAt", { environment = env })()
		local function frames(count, cameraPosition, step)
			step = step or 1 / 30
			camera.CFrame = roblox.CFrame.new(cameraPosition)
			camera.Focus = roblox.CFrame.new(cameraPosition - V3.new(0, 10, 0))
			for _ = 1, count do
				clock += step
				serverNow += step
				updateDisco(step)
			end
		end
		local lobbyCamera = floor + V3.new(20, 12, 40)

		frames(1, lobbyCamera)
		local disco = assert(state(), "The disco is built")
		assert(disco.Root.CFrame.Position.Y > center.Y + 30, "The ball starts high up and comes down")
		local folder = world:FindFirstChild("AdminDiscoLocal")
		assert(folder and lighting:FindFirstChild("AdminDiscoTint"), "Its parts are in the world and its tint on the light")

		-- The ball floats on its own (no chain or cap) and is one set of anchored pieces, each
		-- with its place in the ball's frame: nothing hangs on a joint.
		assert(disco.Root.Anchored and #disco.Tiles >= 150, "A root and its tiles")
		assert(not folder:FindFirstChild("Chain") and not folder:FindFirstChild("Cap"), "No chain or rod holds the ball up")
		for _, descendant in folder:GetDescendants() do
			assert(not descendant:IsA("WeldConstraint") and not descendant:IsA("Weld"), "Nothing is welded")
			if descendant:IsA("BasePart") then
				assert(descendant.Anchored, descendant.Name .. " is anchored")
			end
		end
		assert(#disco.Parts == #disco.Offsets and #disco.Parts == #disco.Tiles + 3, "The root, the core, the wash and every tile move together")
		for _, tile in disco.Tiles do
			-- Round the ball where it is now (still coming down).
			assert(not tile.Part.CanCollide and not tile.Part.CanQuery and not tile.Part.CanTouch and not tile.Part.CastShadow, "...and touches nothing")
		end

		checkSolidBall(disco.Root, disco.Parts, disco.Tiles, DISCO_RADIUS_CHECK, DISCO_TILE_THICKNESS, "The big ball")

		frames(60, lobbyCamera)
		local _, weight = state()
		assert(weight == 1, "Faded in")
		assert((disco.Root.CFrame.Position - center).Magnitude < POSITION_TOLERANCE, "The ball has come down to hang over the middle of the floor")

		-- It turns round its vertical axis, the same small step every frame, and the tiles go
		-- round with it (they are really moved, not left behind on a joint).
		local SPIN = math.rad(assert(tonumber(string.match(effects, "SpinDegrees = (%d+),")), "the spin"))
		local tile = disco.Tiles[1]
		local beforeLook = disco.Root.CFrame.LookVector
		local beforeTile = tile.Part.CFrame.Position - center
		frames(1, lobbyCamera, 1 / 60)
		local turned = math.acos(math.clamp(beforeLook:Dot(disco.Root.CFrame.LookVector), -1, 1))
		assert(math.abs(turned - SPIN / 60) < 1e-3, "A steady turn each frame (" .. turned .. " rad)")
		assert(math.abs(disco.Root.CFrame.UpVector.Y - 1) < 1e-4, "...round the vertical axis")
		local afterTile = tile.Part.CFrame.Position - center
		local flatBefore, flatAfter = V3.new(beforeTile.X, 0, beforeTile.Z), V3.new(afterTile.X, 0, afterTile.Z)
		if flatBefore.Magnitude > 1 then
			local tileTurn = math.acos(math.clamp(flatBefore.Unit:Dot(flatAfter.Unit), -1, 1))
			assert(math.abs(tileTurn - SPIN / 60) < 2e-3, "The tiles turn with the ball (" .. tileTurn .. " rad)")
		end
		assert(math.abs(afterTile.Magnitude - TILE_CENTRE_RADIUS) < POSITION_TOLERANCE, "...staying in its surface")
		local angles = {}
		for _ = 1, 30 do
			local look = disco.Root.CFrame.LookVector
			frames(1, lobbyCamera, 1 / 30)
			table.insert(angles, math.acos(math.clamp(look:Dot(disco.Root.CFrame.LookVector), -1, 1)))
		end
		for _, step in angles do
			assert(math.abs(step - SPIN / 30) < 1e-3, "It never stops or stutters while the party is on")
		end

		-- No beams any more (the user asked them off, 2026-09-18): the ball throws spots of
		-- colour onto the floor, each where its ray from the ball's middle lands, evenly round.
		for _, descendant in folder:GetDescendants() do
			assert(not descendant:IsA("Beam") and not descendant:IsA("Trail"), "The ball draws no beams or trails")
		end
		assert(not folder:FindFirstChild("BeamFloor"), "...nor the beams' floor anchor")
		local yaws = {}
		for _, spot in disco.Spots do
			local landing = spot.Dot.CFrame.Position - V3.new(0, 0.14, 0)
			assert(math.abs(landing.Y - floor.Y) < POSITION_TOLERANCE, "Spot " .. spot.Index .. " lies on the floor")
			local ray = disco.Root.CFrame:VectorToWorldSpace(spot.Direction)
			assert((landing - center).Unit:Dot(ray) > 0.99999, "Spot " .. spot.Index .. " is where the ray from the ball's middle lands")
			assert(spot.Dot.Transparency < 0.5, "Spot " .. spot.Index .. " is lit")
			local flat = (landing - center) * V3.new(1, 0, 1)
			table.insert(yaws, math.atan2(flat.Z, flat.X))
		end
		table.sort(yaws)
		for index = 1, #yaws do
			local nextYaw = if index == #yaws then yaws[1] + math.pi * 2 else yaws[index + 1]
			assert(math.abs((nextYaw - yaws[index]) - math.pi * 2 / #yaws) < 1e-3, "The spots are evenly spaced round the floor")
		end
		local wash = disco.Wash
		assert(wash and wash:IsA("SpotLight") and wash.Brightness > 2 and wash.Range <= 60, "A wide light washes the dance floor")
		assert(wash.Parent.CFrame.LookVector.Y < -0.999, "...pointing straight down")

		-- Colours drift gently.
		local colours = {}
		for index, tile in disco.Tiles do
			colours[index] = tile.Part.Color
		end
		local ambient = select(3, state()).Ambient
		frames(2, lobbyCamera, 1 / 30)
		local biggest, changed = 0, 0
		for index, tile in disco.Tiles do
			local a, b = colours[index], tile.Part.Color
			if a ~= b then
				changed += 1
			end
			if not tile.Mirror then
				-- The hue drifts; only the brightness is allowed to flare on the beat.
				local hueA = a:ToHSV()
				local hueB = b:ToHSV()
				local step = math.abs(hueA - hueB)
				biggest = math.max(biggest, math.min(step, 1 - step))
			end
		end
		assert(changed > #disco.Tiles / 2, "The ball's colours keep moving")
		assert(biggest < 0.02, "...their colours drift smoothly, never jumping (" .. biggest .. ")")
		local ambientNow = select(3, state()).Ambient
		assert(math.max(math.abs(ambient.R - ambientNow.R), math.abs(ambient.G - ambientNow.G), math.abs(ambient.B - ambientNow.B)) < 0.01, "The sky's colour drifts slowly")
		frames(600, lobbyCamera, 1 / 30)
		local later = select(3, state()).Ambient
		assert(math.max(math.abs(ambient.R - later.R), math.abs(ambient.G - later.G), math.abs(ambient.B - later.B)) > 0.03, "...but it does drift")

		-- On the song's beat: the admin's track plays with a kick every half second, and the
		-- ball's glow, the spotlights and the beams flare on each kick.
		local kicks = 0
		song = {
			IsPlaying = true,
			IsA = function(_, class)
				return class == "Sound"
			end,
		}
		local glowAtKick, glowBetween = 0, math.huge
		for frame = 1, 240 do
			local beatTime = (frame / 60) % 0.5
			song.PlaybackLoudness = 60 + 420 * math.exp(-beatTime / 0.04)
			frames(1, lobbyCamera, 1 / 60)
			if disco.Beat.Pulse > 0.95 then
				kicks += 1
				glowAtKick = math.max(glowAtKick, disco.Glow.Brightness)
			elseif disco.Beat.Pulse < 0.1 then
				glowBetween = math.min(glowBetween, disco.Glow.Brightness)
			end
		end
		assert(kicks >= 7 and kicks <= 9, "A flare on every kick of the song (" .. kicks .. " in 4 seconds)")
		assert(math.abs(disco.Beat.Period - 0.5) < 0.05, "...keeping the song's tempo")
		assert(glowAtKick > glowBetween + 4, "The ball's glow jumps on the beat")
		song = nil

		-- The dance floor: light-up tiles covering exactly the lobby's dance floor, just over
		-- the floor and under the beams' dots, a glowing rim round it, and the sign.
		local danceFloor = assert(disco.DanceFloor, "A dance floor under the ball")
		local size = attributes.AdminDiscoFloorSize
		assert(#danceFloor.Tiles == danceFloor.Columns * danceFloor.Rows and #danceFloor.Tiles >= 100, "A full grid of tiles (" .. #danceFloor.Tiles .. ")")
		local cellX, cellZ = size.X / danceFloor.Columns, size.Z / danceFloor.Rows
		assert(cellX >= 8 and cellX <= 12 and cellZ >= 8 and cellZ <= 12, "Tiles about ten studs each way")
		local lowX, highX, lowZ, highZ, distinct = math.huge, -math.huge, math.huge, -math.huge, {}
		for _, tile in danceFloor.Tiles do
			local part = tile.Part
			local position = part.CFrame.Position
			lowX = math.min(lowX, position.X - part.Size.X / 2)
			highX = math.max(highX, position.X + part.Size.X / 2)
			lowZ = math.min(lowZ, position.Z - part.Size.Z / 2)
			highZ = math.max(highZ, position.Z + part.Size.Z / 2)
			local bottom, top = position.Y - part.Size.Y / 2 - floor.Y, position.Y + part.Size.Y / 2 - floor.Y
			assert(bottom > 0 and top < 0.14, "Each tile lies just over the floor, under the beams' dots")
			assert(part.Material == roblox.Enum.Material.Neon and not part.CanCollide and not part.CanQuery and not part.CanTouch, "Glowing tiles nobody bumps into")
			assert(part.Transparency < 0.3, "The tiles are lit")
			distinct[string.format("%.2f %.2f %.2f", part.Color.R, part.Color.G, part.Color.B)] = true
		end
		local gap = 0.5
		assert(math.abs(lowX - (floor.X - size.X / 2 + gap / 2)) < POSITION_TOLERANCE and math.abs(highX - (floor.X + size.X / 2 - gap / 2)) < POSITION_TOLERANCE, "Edge to edge across the floor")
		assert(math.abs(lowZ - (floor.Z - size.Z / 2 + gap / 2)) < POSITION_TOLERANCE and math.abs(highZ - (floor.Z + size.Z / 2 - gap / 2)) < POSITION_TOLERANCE, "...and along it")
		-- Its light shows: four of them in turn, each flowing into the next, never jumping.
		local current, following, blend = floorShowsAt(0)
		assert(current == 1 and following == 2 and blend == 0, "The first show plays on its own")
		current, following, blend = floorShowsAt(9)
		assert(current == 1 and following == 2 and math.abs(blend - 0.5) < 1e-9, "...and flows into the next over its last two seconds")
		current, following, blend = floorShowsAt(10)
		assert(current == 2 and following == 3 and blend == 0, "Then the next plays")
		current, following = floorShowsAt(35)
		assert(current == 4 and following == 1, "...and after the fourth, the first again")
		local most, jump = 0, 0
		local previous = {}
		for step = 0, 40 * 20 do
			local t = 5000 + step / 20
			local seen, count = {}, 0
			for index, tile in danceFloor.Tiles do
				local colour = floorColour(tile.Column, tile.Row, danceFloor.Columns, danceFloor.Rows, t)
				local key = string.format("%.2f %.2f %.2f", colour.R, colour.G, colour.B)
				if not seen[key] then
					seen[key] = true
					count += 1
				end
				local before = previous[index]
				if before then
					jump = math.max(jump, math.abs(before.R - colour.R), math.abs(before.G - colour.G), math.abs(before.B - colour.B))
				end
				previous[index] = colour
			end
			most = math.max(most, count)
		end
		assert(most >= 20, "A floor full of colours (" .. most .. ")")
		assert(jump < 0.2, "Every tile's colour changes gently, frame to frame and show to show (" .. jump .. ")")
		assert(#danceFloor.Rim == 4, "A glowing rim on all four sides")
		for _, strip in danceFloor.Rim do
			local offset = strip.CFrame.Position - floor
			assert(math.abs(offset.X) >= size.X / 2 - POSITION_TOLERANCE or math.abs(offset.Z) >= size.Z / 2 - POSITION_TOLERANCE, "The rim runs round the outside")
		end
		assert(disco.Sign.Enabled and disco.Sign.Title.Text == "DISCO PARTY" and string.find(disco.Sign.Hint.Text, "dance", 1, true), "A sign over the ball says how to dance")

		-- Dancing: standing still on the floor while the disco is on.
		local tracks = {}
		local animator = { FindFirstChildOfClass = function() end }
		function animator:LoadAnimation(animation)
			local track = { AnimationId = animation.AnimationId, Playing = false, Stops = 0 }
			function track:Play()
				self.Playing = true
			end
			function track:Stop()
				self.Playing = false
				self.Stops += 1
			end
			table.insert(tracks, track)
			return track
		end
		local humanoid = {
			MoveDirection = V3.new(0, 0, 0),
			FloorMaterial = roblox.Enum.Material.Plastic,
			Sit = false,
			RigType = roblox.Enum.HumanoidRigType.R15,
			FindFirstChildOfClass = function(_, class)
				return if class == "Animator" then animator else nil
			end,
		}
		local body = { Position = floor + V3.new(10, 3, -12) }
		local playerAttributes, characterAttributes = {}, {}
		local model = { GetAttribute = function(_, name)
			return characterAttributes[name]
		end }
		who.humanoid, who.root = humanoid, body
		playerObject.Character = model
		playerObject.GetAttribute = function(_, name)
			return playerAttributes[name]
		end
		local function danceFrames(seconds)
			for _ = 1, math.floor(seconds * 30 + 0.5) do
				clock += 1 / 30
				serverNow += 1 / 30
				updateDisco(1 / 30)
				updateDance(1 / 30)
			end
		end
		local function playing()
			for _, track in tracks do
				if track.Playing then
					return track
				end
			end
			return nil
		end
		danceFrames(0.2)
		assert(playing() == nil, "Not straight away: a player just passing over the floor does not dance")
		danceFrames(0.3)
		local dance = assert(playing(), "Standing still on the floor, the player dances")
		assert(dance.Priority == roblox.Enum.AnimationPriority.Action3 and dance.Looped == true, "Over the character's own idle and jump animations, on a loop")
		assert(dance.AnimationId == "rbxassetid://507771019" or dance.AnimationId == "rbxassetid://507776043" or dance.AnimationId == "rbxassetid://507777268", "One of Roblox's R15 dances")
		danceFrames(10.2)
		local next = assert(playing(), "Still dancing")
		assert(next ~= dance and next.AnimationId ~= dance.AnimationId and dance.Stops > 0, "A new dance every little while, flowing from the last")
		for _, case in {
			{ "moving", function() humanoid.MoveDirection = V3.new(1, 0, 0) end, function() humanoid.MoveDirection = V3.new(0, 0, 0) end },
			{ "jumping", function() humanoid.FloorMaterial = roblox.Enum.Material.Air end, function() humanoid.FloorMaterial = roblox.Enum.Material.Plastic end },
			{ "off the floor", function() body.Position = floor + V3.new(size.X, 3, 0) end, function() body.Position = floor + V3.new(10, 3, -12) end },
			{ "on a treadmill", function() playerAttributes.IsOnTreadmill = true end, function() playerAttributes.IsOnTreadmill = nil end },
			{ "ragdolled", function() characterAttributes.Ragdolled = true end, function() characterAttributes.Ragdolled = nil end },
			{ "sitting", function() humanoid.Sit = true end, function() humanoid.Sit = false end },
		} do
			assert(playing(), "Dancing before " .. case[1])
			case[2]()
			danceFrames(1 / 30)
			assert(playing() == nil, "The dance stops when " .. case[1])
			case[3]()
			danceFrames(0.5)
			assert(playing(), "...and starts again standing still once more (" .. case[1] .. ")")
		end
		humanoid.RigType = roblox.Enum.HumanoidRigType.R6
		humanoid.MoveDirection = V3.new(1, 0, 0)
		danceFrames(1 / 30)
		humanoid.MoveDirection = V3.new(0, 0, 0)
		danceFrames(0.5)
		assert(string.find("rbxassetid://182435998 rbxassetid://182436842 rbxassetid://182436935", playing().AnimationId, 1, true), "R6 characters get R6 dances")
		who.humanoid, who.root = nil, nil
		danceFrames(1 / 30)
		assert(playing() == nil, "No character, no dance")

		-- Away from the lobby: the ball's spots fade, and the coloured lights come round the
		-- player instead.
		local far = V3.new(5000, 150, 900)
		frames(40, far, 1 / 30)
		assert(disco.Near < 0.01, "Far from the lobby the ball's show fades")
		for _, spot in disco.Spots do
			assert(spot.Dot.Transparency > 0.99, "...its spots")
		end
		for _, wanderer in disco.Wanderers do
			local position = wanderer.Part.CFrame.Position
			assert((V3.new(position.X, 0, position.Z) - V3.new(5000, 0, 900)).Magnitude < 60, "The coloured lights wander round the player")
		end

		-- Off the dance floor a small copy of the ball follows the player: over their head,
		-- turning, its light and their outline (a Highlight) running through the colours.
		-- Back on the floor it goes.
		do
			local model = roblox.Instance.new("Model")
			model.Name = "Dancer"
			local body = roblox.Instance.new("Part")
			body.Name = "HumanoidRootPart"
			body.Parent = model
			local offFloor = floor + V3.new(90, 3, 10)
			body.CFrame = roblox.CFrame.new(offFloor)
			playerObject.Character = model
			testPlayers = { playerObject }
			frames(3, lobbyCamera, 1 / 30)
			local copy = folder:FindFirstChild("AdminDiscoFollower")
			assert(copy, "Off the floor a copy of the ball follows the player")
			local copyRoot = copy:FindFirstChild("BallRoot")
			local lift = copyRoot.CFrame.Position - offFloor
			assert(lift.Y > 5 and lift.Y < 8 and V3.new(lift.X, 0, lift.Z).Magnitude < 0.5, "...a little over their head")
			local tiles = 0
			for _, part in copy:GetChildren() do
				if part:IsA("BasePart") then
					assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "The copy touches nothing")
					if part.Name == "Mirror" or part.Name == "Neon" then
						tiles += 1
					end
				end
			end
			assert(tiles >= 16 and tiles <= 40, "A small ball of tiles, light enough to follow every frame (" .. tiles .. ")")
			local copyTiles = {}
			for _, part in copy:GetChildren() do
				if part.Name == "Mirror" or part.Name == "Neon" then
					local offset = part.CFrame.Position - copyRoot.CFrame.Position
					table.insert(copyTiles, { Part = part, Latitude = math.asin(math.clamp(offset.Unit.Y, -1, 1)) })
				end
			end
			local followerRadius = assert(tonumber(string.match(effects, "local FOLLOWER = {\n\tRadius = ([%d.]+),")), "the copy's radius")
			local followerThickness = assert(tonumber(string.match(effects, "local FOLLOWER = {.-TileThickness = ([%d.]+),")), "the copy's tile thickness")
			checkSolidBall(copyRoot, copy:GetChildren(), copyTiles, followerRadius, followerThickness, "The copy over a player")
			assert(string.find(effects, "tile.Part.Color = MIRROR:Lerp(Color3.new(1, 1, 1), glint)", 1, true), "Its silver tiles glint now and then")
			local outline = copy:FindFirstChildOfClass("Highlight")
			assert(outline and outline.Adornee == model and outline.FillTransparency == 1, "The player's outline is lit (a Highlight on their character)")
			assert(outline.OutlineTransparency < 0.01, "...fully, while the party is on")
			local look, colour = copyRoot.CFrame.LookVector, outline.OutlineColor
			frames(6, lobbyCamera, 1 / 30)
			assert(copyRoot.CFrame.LookVector:Dot(look) < 0.999, "The copy turns")
			assert(outline.OutlineColor ~= colour, "The outline's colour changes")
			assert(copyRoot:FindFirstChildOfClass("PointLight").Brightness > 1, "The copy lights the player")
			-- Following: the player moves and the copy catches up.
			local moved = offFloor + V3.new(0, 0, 30)
			body.CFrame = roblox.CFrame.new(moved)
			frames(60, lobbyCamera, 1 / 30)
			assert((copyRoot.CFrame.Position - (moved + V3.new(0, 6.5, 0))).Magnitude < 0.6, "The copy follows the player")
			-- On the dance floor the big ball is there: no copy.
			body.CFrame = roblox.CFrame.new(floor + V3.new(0, 3, 0))
			frames(1, lobbyCamera, 1 / 30)
			assert(not folder:FindFirstChild("AdminDiscoFollower"), "Back on the dance floor the copy goes")
			body.CFrame = roblox.CFrame.new(offFloor)
			frames(2, lobbyCamera, 1 / 30)
			assert(folder:FindFirstChild("AdminDiscoFollower"), "...and comes back off it")
			testPlayers = {}
			frames(1, lobbyCamera, 1 / 30)
			assert(not folder:FindFirstChild("AdminDiscoFollower"), "A player who leaves takes no copy with them")
			testPlayers = { playerObject }
			frames(1, lobbyCamera, 1 / 30)
		end

		-- Ending: fades away and cleans up.
		attributes.AdminDiscoUntil = nil
		attributes.AdminDiscoCenter = nil
		attributes.AdminDiscoFloor = nil
		frames(20, lobbyCamera, 1 / 30)
		assert(state() ~= nil and folder.Parent ~= nil, "It fades out rather than vanishing")
		frames(40, lobbyCamera, 1 / 30)
		local after, afterWeight = state()
		assert(after == nil and afterWeight == 0 and folder.Parent == nil and not lighting:FindFirstChild("AdminDiscoTint"), "Faded out: the ball, every light and the tint are gone")
	end
	print("PASS World effects: a snowfall that reaches the ground with a winter sky that eases back, a disco night with sweeping spotlights anywhere on the map, the rainbow treadmill")
end

print("ALL ADMIN ABUSE PANEL CHECKS PASSED")
