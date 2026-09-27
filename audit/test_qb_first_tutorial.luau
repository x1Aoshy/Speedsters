-- audit/test_qb_first_tutorial.luau  (2026-09-21)
-- "Sometimes the tutorial doesn't show AT ALL for new players." Runs the REAL
-- FirstTimeTutorial.server.luau (luau.load with stand-ins for Players, the player's attributes
-- and change signals, the task scheduler on a manual clock, Config and _G.SpeedsterSavePlayer)
-- and proves:
--   1. a new save starts the tutorial (Active at once) and the seen flag is NOT saved at start;
--   2. step timers wait for the HumanoidRootPart; both timeouts save nothing, a rejoin starts again;
--   3. claiming the first Win pad after Step 2 timed out saves the flag exactly once;
--   4. a failing save is retried with backoff (surviving the projection writing false back),
--      and once more on leave when every retry failed;
--   5. the re-offer cap: Rebirths >= 1 marks it seen silently without starting;
--   6. World 3 and World 2: the script returns before connecting PlayerAdded;
-- and, on the client, 7. the World 3 guard and 8. the step label (a BillboardGui built, shown,
-- hidden and destroyed with the beam, running the real functions on Lune instances).
--   lune run audit/test_qb_first_tutorial.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local SERVER = "src/common/ServerScriptService/Social/FirstTimeTutorial.server.luau"
local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local serverSource = fs.readFile(SERVER)
local clientSource = fs.readFile(CLIENT)

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

for _, path in { SERVER, CLIENT } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("both tutorial sources compile")

----------------------------------------------------------------------
-- Stand-ins
----------------------------------------------------------------------
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		local connection = { Connected = true }
		self.handlers[connection] = fn
		function connection.Disconnect()
			connection.Connected = false
			signal.handlers[connection] = nil
		end
		return connection
	end
	function signal:Fire(...)
		local list = {}
		for connection, fn in self.handlers do
			table.insert(list, { connection, fn })
		end
		for _, item in list do
			if item[1].Connected then
				item[2](...)
			end
		end
	end
	function signal:Count()
		local count = 0
		for _ in self.handlers do
			count += 1
		end
		return count
	end
	return signal
end

-- One world per run: a manual clock, a task library on coroutines, Players and the script.
local function newWorld(config, saveBehaviour)
	local world = { clock = 0, queue = {}, seq = 0, saves = {}, warnings = {} }

	local function schedule(at, fn, ...)
		world.seq += 1
		table.insert(world.queue, { at = at, seq = world.seq, fn = fn, args = table.pack(...) })
	end
	local function run(fn, ...)
		local co = coroutine.create(fn)
		local ok, problem = coroutine.resume(co, ...)
		assert(ok, tostring(problem))
	end
	local task = {}
	function task.spawn(fn, ...)
		run(fn, ...)
	end
	function task.defer(fn, ...)
		schedule(world.clock, fn, ...)
	end
	function task.delay(seconds, fn, ...)
		schedule(world.clock + (seconds or 0), fn, ...)
	end
	function task.wait(seconds)
		local co = coroutine.running()
		schedule(world.clock + (seconds or 0), function()
			local ok, problem = coroutine.resume(co)
			assert(ok, tostring(problem))
		end)
		return coroutine.yield()
	end
	-- Runs everything due up to clock + dt, in time order.
	function world.advance(dt)
		local target = world.clock + dt
		while true do
			local best, bestIndex = nil, nil
			for index, item in world.queue do
				if item.at <= target and (not best or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
					best, bestIndex = item, index
				end
			end
			if not best then
				break
			end
			table.remove(world.queue, bestIndex)
			world.clock = math.max(world.clock, best.at)
			run(best.fn, table.unpack(best.args, 1, best.args.n))
		end
		world.clock = target
	end

	local Players = { PlayerAdded = newSignal(), PlayerRemoving = newSignal(), list = {} }
	function Players:GetPlayers()
		return table.clone(self.list)
	end
	world.Players = Players

	function world.newPlayer(attributes)
		local player = { Name = "Newbie", UserId = 1, Parent = nil, Character = nil, attributes = {}, signals = {} }
		for key, value in attributes do
			player.attributes[key] = value
		end
		function player:GetAttribute(name)
			return self.attributes[name]
		end
		function player:GetAttributeChangedSignal(name)
			self.signals[name] = self.signals[name] or newSignal()
			return self.signals[name]
		end
		function player:SetAttribute(name, value)
			if self.attributes[name] == value then
				return
			end
			self.attributes[name] = value
			if self.signals[name] then
				self.signals[name]:Fire()
			end
		end
		player.AncestryChanged = newSignal()
		function player:Listeners(name)
			return self.signals[name] and self.signals[name]:Count() or 0
		end
		function player:GiveCharacter()
			local root = { Name = "HumanoidRootPart" }
			self.Character = {
				FindFirstChild = function(_, name)
					return if name == "HumanoidRootPart" then root else nil
				end,
			}
		end
		return player
	end
	function world.join(player)
		player.Parent = Players
		table.insert(Players.list, player)
		Players.PlayerAdded:Fire(player)
		world.advance(0)
	end
	function world.leave(player)
		Players.PlayerRemoving:Fire(player)
		player.Parent = nil
		table.remove(Players.list, table.find(Players.list, player))
		world.advance(0)
	end

	local G = {}
	G.SpeedsterSavePlayer = function(player, reason, waitForCompletion)
		local attempt = #world.saves + 1
		local result = saveBehaviour == nil or saveBehaviour(attempt, player)
		table.insert(world.saves, { reason = reason, wait = waitForCompletion, seen = player:GetAttribute("FirstTimeTutorialSeen"), ok = result })
		return result
	end
	world.G = G

	local configMarker = {}
	local shared = { WaitForChild = function() return configMarker end }
	local services = {
		Players = Players,
		ReplicatedStorage = { WaitForChild = function() return shared end },
		RunService = { IsStudio = function() return false end },
	}
	local env = {
		game = { GetService = function(_, name) return assert(services[name], "unexpected service " .. name) end },
		require = function(module)
			assert(module == configMarker, "unexpected require")
			return config
		end,
		task = task,
		_G = G,
		os = { clock = function() return world.clock end },
		Instance = { new = function(className) error("unexpected Instance.new " .. className) end },
		print = function() end,
		warn = function(text) table.insert(world.warnings, text) end,
		math = math, table = table, string = string, tonumber = tonumber, tostring = tostring, pcall = pcall,
		ipairs = ipairs, pairs = pairs, type = type, select = select, error = error, assert = assert,
	}
	local chunk = luau.load(serverSource, { debugName = "FirstTimeTutorial.server", environment = env })
	run(chunk)
	world.advance(0)
	return world
end

local W1 = { IsWorld2Place = false, IsWorld3Place = false, IsNewWorld1Map = true }
local NEW_SAVE = { DataLoaded = true, FirstTimeTutorialSeen = false, Rebirths = 0 }

----------------------------------------------------------------------
-- 1 + 2. New save: starts, nothing saved; timers wait for the root; timeouts save nothing
----------------------------------------------------------------------
local stickyWorld, stickyPlayer
do
	local world = newWorld(W1)
	local player = world.newPlayer(NEW_SAVE)
	world.join(player)
	assert(player:GetAttribute("FirstTimeTutorialActive") == true, "a new save did not start the tutorial")
	assert(player:GetAttribute("FirstTimeTutorialStep") == 1, "Step 1 not shown")
	assert(player:GetAttribute("FirstTimeTutorialSeen") ~= true, "REGRESSION: seen flag set at start")
	assert(#world.saves == 0, "REGRESSION: seen flag saved at start")
	pass("new save: Active and Step 1 at once, seen flag neither set nor saved at start")

	-- No character yet (slow phone, loading screen): the 102 s window must not run.
	world.advance(300)
	assert(player:GetAttribute("FirstTimeTutorialStep") == 1 and player:GetAttribute("FirstTimeTutorialActive") == true,
		"Step 1 timed out before the character existed")
	player:GiveCharacter()
	world.advance(0.25) -- the poll sees the root and starts the clock
	world.advance(101)
	assert(player:GetAttribute("FirstTimeTutorialStep") == 1, "Step 1 ended early")
	world.advance(1.5)
	assert(player:GetAttribute("FirstTimeTutorialStep") == 0, "Step 1 did not time out 102 s after the character")
	world.advance(0.65)
	assert(player:GetAttribute("FirstTimeTutorialStep") == 2, "Step 2 did not follow")
	world.advance(102.5)
	assert(player:GetAttribute("FirstTimeTutorialActive") == false, "Step 2 did not time out")
	assert(player:GetAttribute("FirstTimeTutorialSeen") ~= true and #world.saves == 0, "a timeout saved the seen flag")
	pass("step timers start only with the HumanoidRootPart; both timeouts end the tutorial without saving it")

	-- 2. Rejoin on a fresh server: offered again.
	local world2 = newWorld(W1)
	local again = world2.newPlayer({ DataLoaded = true, FirstTimeTutorialSeen = player:GetAttribute("FirstTimeTutorialSeen") == true, Rebirths = 0 })
	world2.join(again)
	assert(again:GetAttribute("FirstTimeTutorialActive") == true and again:GetAttribute("FirstTimeTutorialStep") == 1,
		"REGRESSION: a player who never claimed the pad did not get the tutorial on the next join")
	pass("after both timeouts the next join starts the tutorial again")

	stickyWorld, stickyPlayer = world, player
end

----------------------------------------------------------------------
-- 3. Claim the first Win pad after Step 2 timed out: saved exactly once
----------------------------------------------------------------------
do
	local world, player = stickyWorld, stickyPlayer
	player:SetAttribute("LastCompletedSafeZone", 1)
	world.advance(0)
	assert(player:GetAttribute("FirstTimeTutorialSeen") == true, "claim did not mark seen")
	assert(#world.saves == 1 and world.saves[1].reason == "first_time_tutorial_completed" and world.saves[1].seen == true,
		"claim did not save the seen flag with the completion reason")
	player:SetAttribute("LastCompletedSafeZone", 2)
	world.advance(60)
	assert(#world.saves == 1, "a second claim saved again")
	assert(player:Listeners("LastCompletedSafeZone") == 0, "the claim watcher stayed connected after a good save")
	pass("first Win pad claimed after the Step 2 timeout: seen saved exactly once, watcher disconnected")
end

-- Completing the steps in order: Step 1 on the treadmill, Step 2 on the pad.
do
	local world = newWorld(W1)
	local player = world.newPlayer(NEW_SAVE)
	player:GiveCharacter()
	world.join(player)
	player:SetAttribute("OnTutorialBrownTreadmill", true)
	world.advance(1)
	assert(player:GetAttribute("FirstTimeTutorialStep") == 2, "treadmill did not finish Step 1")
	assert(#world.saves == 0, "Step 1 saved the flag")
	player:SetAttribute("LastCompletedSafeZone", 1)
	world.advance(0)
	assert(player:GetAttribute("FirstTimeTutorialActive") == false, "pad did not finish Step 2")
	assert(#world.saves == 1 and world.saves[1].reason == "first_time_tutorial_completed", "completion not saved once")
	world.advance(500)
	assert(#world.saves == 1, "timers saved again after completion")
	pass("normal run: treadmill -> Step 2, pad -> done and saved once")
end

----------------------------------------------------------------------
-- 4. A failing save is retried, even when the projection writes false back
----------------------------------------------------------------------
do
	local world = newWorld(W1, function(attempt) return attempt >= 3 end)
	local player = world.newPlayer(NEW_SAVE)
	player:GiveCharacter()
	world.join(player)
	player:SetAttribute("LastCompletedSafeZone", 1)
	world.advance(0)
	assert(#world.saves == 1 and world.saves[1].ok == false, "first attempt missing")
	-- StatsProjection re-projects the (still false) profile value on the next profile change.
	player:SetAttribute("FirstTimeTutorialSeen", false)
	world.advance(2)
	assert(#world.saves == 2 and world.saves[2].seen == true, "retry did not set the attribute again before saving")
	world.advance(5)
	assert(#world.saves == 3 and world.saves[3].ok == true, "third attempt missing")
	world.advance(200)
	assert(#world.saves == 3, "kept saving after success")
	assert(player:GetAttribute("FirstTimeTutorialSeen") == true)
	assert(player:Listeners("LastCompletedSafeZone") == 0, "watcher kept after the save landed")
	pass("failing save retried with backoff (2 s, 5 s) and re-sets the attribute each try; stops once saved")
end

do
	local world = newWorld(W1, function() return false end)
	local player = world.newPlayer(NEW_SAVE)
	player:GiveCharacter()
	world.join(player)
	player:SetAttribute("LastCompletedSafeZone", 1)
	world.advance(600)
	assert(#world.saves == 6, "expected 1 attempt + 5 retries, got " .. #world.saves)
	assert(player:Listeners("LastCompletedSafeZone") == 1, "watcher dropped while the flag is still unsaved")
	-- A later claim starts another round.
	player:SetAttribute("LastCompletedSafeZone", 2)
	world.advance(0)
	assert(#world.saves == 7, "a new claim did not retry the unsaved flag")
	world.advance(600)
	local beforeLeave = #world.saves
	world.leave(player)
	assert(#world.saves == beforeLeave + 1 and world.saves[#world.saves].reason == "first_time_tutorial_completed",
		"no last save attempt on leave")
	assert(player:Listeners("LastCompletedSafeZone") == 0, "watcher not disconnected on leave")
	world.advance(600)
	assert(#world.saves == beforeLeave + 1, "kept saving after the player left")
	pass("every retry failing: watcher stays, next claim retries, one last try on leave, then all disconnected")
end

-- Leaving before any claim: nothing saved, nothing left connected.
do
	local world = newWorld(W1)
	local player = world.newPlayer(NEW_SAVE)
	world.join(player)
	world.leave(player)
	world.advance(600)
	assert(#world.saves == 0, "leaving before the claim saved the flag")
	assert(player:Listeners("LastCompletedSafeZone") == 0 and player:Listeners("OnTutorialBrownTreadmill") == 0,
		"connections left after leave")
	pass("leaving before the claim saves nothing and disconnects the watcher")
end

----------------------------------------------------------------------
-- 5. Re-offer cap
----------------------------------------------------------------------
do
	assert(serverSource:find("KNOWN_LOOP_REBIRTHS = 1", 1, true), "cap rule changed; update this test")
	local world = newWorld(W1)
	local player = world.newPlayer({ DataLoaded = true, FirstTimeTutorialSeen = false, Rebirths = 1 })
	world.join(player)
	assert(player:GetAttribute("FirstTimeTutorialActive") ~= true, "a rebirthed player got the tutorial")
	assert(player:GetAttribute("FirstTimeTutorialSeen") == true, "a rebirthed player was not marked seen")
	assert(#world.saves == 1 and world.saves[1].reason == "first_time_tutorial_known_loop", "cap did not save")
	world.advance(600)
	assert(#world.saves == 1)

	local veteran = newWorld(W1)
	local old = veteran.newPlayer({ DataLoaded = true, FirstTimeTutorialSeen = true, Rebirths = 0 })
	veteran.join(old)
	assert(old:GetAttribute("FirstTimeTutorialActive") ~= true and #veteran.saves == 0, "a seen save started again")
	pass("re-offer cap: Rebirths >= 1 marks seen silently (saved once), a seen save never starts")
end

----------------------------------------------------------------------
-- 6. World 3 and World 2: off before PlayerAdded is connected
----------------------------------------------------------------------
for _, config in { { IsWorld3Place = true, IsWorld2Place = false }, { IsWorld2Place = true, IsWorld3Place = false } } do
	local world = newWorld(config)
	assert(world.Players.PlayerAdded:Count() == 0 and world.Players.PlayerRemoving:Count() == 0,
		"the tutorial connected PlayerAdded outside World 1")
	local player = world.newPlayer(NEW_SAVE)
	world.join(player)
	for name in player.attributes do
		assert(not name:find("FirstTimeTutorialActive", 1, true) and not name:find("FirstTimeTutorialStep", 1, true),
			"tutorial attribute set outside World 1: " .. name)
	end
	assert(#world.saves == 0)
end
pass("server returns before connecting PlayerAdded in World 3 and World 2")

----------------------------------------------------------------------
-- 7. Client: World 3 guard before any work
----------------------------------------------------------------------
do
	local src = clientSource:gsub("\r\n", "\n")
	local guard = assert(src:find("or Config.IsWorld3Place\nthen", 1, true), "client has no World 3 guard")
	local guardReturn = assert(src:find("\treturn\nend", guard, true))
	local firstWork = assert(src:find("local FORCE_TUTORIAL_FOR_EVERYONE", 1, true))
	assert(guardReturn < firstWork, "the client's World 3 guard returns too late")
	assert(src:find("or Config.IsWorld2Place\n", 1, true) and src:find("or Config.IsWorld2Place\n", 1, true) < guard,
		"the World 2 guard was lost")
	assert(not src:find("ScreenGui", 1, true), "the tutorial client must not add a ScreenGui")
	pass("client returns in World 3 (and World 2) before any work, and adds no ScreenGui")
end

----------------------------------------------------------------------
-- 8. Client: the step label lives and dies with the beam (real functions, Lune instances)
----------------------------------------------------------------------
do
	local src = clientSource:gsub("\r\n", "\n")
	local function between(startMarker, endMarker)
		local a = assert(src:find(startMarker, 1, true), "missing " .. startMarker)
		local b = assert(src:find(endMarker, a, true), "missing " .. endMarker)
		return src:sub(a, b - 1)
	end
	-- Constants and state exactly as the script declares them.
	local header = between("local ARROW_TEXTURE_ID", "local completeSound = SoundService")
	local body = between("local function createInvisibleAnchor", "-- The \"your first aura\" guide")
	local chunk = "local FORCE_TUTORIAL_FOR_EVERYONE = false\n" .. header .. "\n" .. body .. [[

return {
	ensure = ensureBeamVisual,
	setVisible = setBeamVisible,
	destroy = destroyBeamVisual,
	setStep = function(step) displayedStep = step end,
	state = function() return beamFolder, goalPart, stepLabel, tutorialBeam end,
}
]]
	local Workspace = rb.Instance.new("Folder")
	Workspace.Name = "Workspace"
	local noop = function() end
	-- 2026-09-22: the label's words are Shared/TutorialText keys in the player's language (loaded
	-- here with Font/Enum, as on a client).
	local TutorialText = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TutorialText.luau"), {
		debugName = "TutorialText", environment = { Font = rb.Font, Enum = rb.Enum, setmetatable = setmetatable,
			pcall = pcall, type = type, tostring = tostring, string = string, table = table },
	})()
	local EN = TutorialText.Strings.en
	local function loadBeam(stepLanguage, workspace)
		return luau.load(chunk, { debugName = "FirstTimeTutorial.client(beam)", environment = {
			Instance = rb.Instance, Vector3 = rb.Vector3, Color3 = rb.Color3, UDim2 = rb.UDim2, Enum = rb.Enum,
			ColorSequence = rb.ColorSequence, NumberSequence = rb.NumberSequence, Font = rb.Font,
			Workspace = workspace, math = math, tonumber = tonumber,
			disconnectTargetWatch = noop, disconnectTargetAncestryWatch = noop, disconnectTargetDeckWatch = noop,
			player = {}, getTargetPosition = noop, TutorialText = TutorialText, stepLanguage = stepLanguage,
		} })()
	end
	local api = loadBeam("en", Workspace)

	api.setStep(1)
	api.ensure()
	local folder, goal, label, beam = api.state()
	assert(folder and folder.Parent == Workspace and beam, "beam not built")
	assert(label and label.ClassName == "BillboardGui", "no BillboardGui built with the beam")
	assert(label.Parent == goal and label.Adornee == goal, "label is not on the beam's goal anchor")
	assert(label.AlwaysOnTop == true and label.MaxDistance > 0, "label must be AlwaysOnTop with a max distance")
	-- Pixel floor: at the ~214-stud spawn distance a studs-only label was ~5 px tall on a phone.
	-- The offset keeps it readable far away; a small stud part lets it grow a little up close,
	-- but it must not grow into a screen-filling sign (stud part capped at 6x2).
	assert(label.Size.X.Offset >= 150 and label.Size.Y.Offset >= 36, "label needs a pixel floor to stay readable from spawn")
	assert(label.Size.X.Offset <= 320 and label.Size.Y.Offset <= 80, "label pixel size too large for a phone")
	assert(label.Size.X.Scale <= 6 and label.Size.Y.Scale <= 2, "label stud part too large up close")
	local text = label:FindFirstChildOfClass("TextLabel")
	assert(text and text.TextScaled and text.TextColor3 == rb.Color3.fromRGB(255, 255, 255), "label text must be white, scaled")
	assert(text.FontFace.Family:find("Fredoka", 1, true), "label must use FredokaOne")
	local stroke = text:FindFirstChildOfClass("UIStroke")
	assert(stroke and stroke.Color == rb.Color3.fromRGB(11, 27, 61), "label outline must be the HUD navy")
	assert(label.Enabled == false, "label visible before the beam")

	assert(text.AutoLocalize == false, "label already in the player's language: AutoLocalize off")
	api.setVisible(true)
	assert(EN.StepTrain == "TRAIN HERE!" and EN.StepClaimWins == "CLAIM YOUR WINS!", "English step labels changed")
	assert(beam.Enabled and label.Enabled and text.Text == EN.StepTrain, "Step 1 label not shown with the beam")
	api.setVisible(false)
	assert(not beam.Enabled and not label.Enabled, "label stayed up when the beam hid (target streamed out)")
	api.setStep(2)
	api.setVisible(true)
	assert(label.Enabled and text.Text == EN.StepClaimWins, "Step 2 label wrong")

	-- A Spanish runner reads Spanish (FredokaOne kept); a Russian one gets a font with Cyrillic.
	for lang, family in { es = "Fredoka", pt = "Fredoka", ru = "BuilderSans", ar = "BuilderSans", th = "BuilderSans" } do
		local other = rb.Instance.new("Folder")
		local localized = loadBeam(lang, other)
		localized.setStep(1)
		localized.ensure()
		local _, _, otherLabel = localized.state()
		local otherText = otherLabel:FindFirstChildOfClass("TextLabel")
		localized.setVisible(true)
		assert(otherText.Text == TutorialText.Strings[lang].StepTrain and otherText.Text ~= EN.StepTrain, lang .. " Step 1 label")
		assert(otherText.AutoLocalize == false and otherText.FontFace.Family:find(family, 1, true), lang .. " label font/AutoLocalize")
		localized.setStep(2)
		localized.setVisible(true)
		assert(otherText.Text == TutorialText.Strings[lang].StepClaimWins, lang .. " Step 2 label")
		localized.destroy()
	end

	-- A torn visual (beam removed) is rebuilt whole, label included, without leaking the old folder.
	beam.Parent = nil
	api.ensure()
	local folder2, _, label2 = api.state()
	assert(folder2 ~= folder and folder.Parent == nil and label2 and label2.Parent, "torn visual not rebuilt with its label")

	api.destroy()
	local folder3, goal3, label3, beam3 = api.state()
	assert(folder3 == nil and goal3 == nil and label3 == nil and beam3 == nil, "destroy left the label behind")
	assert(label2.Parent == nil or label2:FindFirstAncestorOfClass("Folder") == nil or folder2.Parent == nil, "old label still in Workspace")
	assert(#Workspace:GetChildren() == 0, "Workspace still holds tutorial visuals")
	pass("step label: BillboardGui on the beam's goal anchor, FredokaOne white on navy, shown/hidden/rebuilt/destroyed with the beam, in the player's language")
end

-- Bootstrap's own PlayerRemoving (the real cleanupPlayer): an unsaved "seen" (attribute true,
-- profile false) is committed BEFORE Release closes the profile, whatever order the two
-- PlayerRemoving handlers run in (the final review's finding, 2026-09-21).
do
	local fs2 = require("@lune/fs")
	local luau2 = require("@lune/luau")
	local source = fs2.readFile("src/common/ServerScriptService/Bootstrap.server.luau"):gsub("\r\n", "\n")
	local a = assert(source:find("local function cleanupPlayer(player: Player)", 1, true), "cleanupPlayer not found")
	local b = assert(source:find("\nPlayers.PlayerAdded:Connect(setupPlayer)", a, true), "cleanupPlayer end not found")
	local chunk = source:sub(a, b - 1):gsub("%(player: Player%)", "(player)") .. "\nreturn cleanupPlayer\n"
	local function run(attributeSeen, profileSeen, loaded)
		local calls = {}
		local profile = { FirstTimeTutorialSeen = profileSeen }
		local DataService = {
			GetHandle = function(userId)
				return if loaded then { userId = userId } else nil
			end,
			Inspect = function()
				return { ok = true, value = { profile = profile } }
			end,
			NewOperationId = function()
				return "op"
			end,
			Commit = function(_, request)
				table.insert(calls, "commit")
				for _, command in request.commands do
					assert(command.kind == "SetPersistent" and command.key == "FirstTimeTutorialSeen" and command.value == true, "unexpected command")
					profile.FirstTimeTutorialSeen = true
				end
				return { kind = "Committed" }
			end,
			Release = function()
				table.insert(calls, "release")
				return { kind = "Released" }
			end,
		}
		local cleanup = luau2.load(chunk, { debugName = "cleanupPlayer", environment = {
			DataService = DataService, StatsProjection = { Detach = function() end },
			boostStaminaByPlayer = {}, boostMaxByPlayer = {}, lastBoostUseAt = {}, staminaPublicationByPlayer = {},
			-- 2026-09-24: the before-release hooks (AFK Mode, quests); none registered here, their
			-- order against Release is covered by audit/test_retention_p0.
			beforeReleaseCallbacks = {}, tostring = tostring,
			task = { spawn = function() end, wait = function() end }, warn = function() end, pcall = pcall,
		} })()
		local player = { UserId = 7 }
		function player:GetAttribute(name)
			return if name == "FirstTimeTutorialSeen" then attributeSeen else nil
		end
		cleanup(player)
		return table.concat(calls, ","), profile.FirstTimeTutorialSeen
	end
	local order, saved = run(true, false, true)
	assert(order == "commit,release" and saved == true, "unsaved seen not committed before Release: " .. order)
	order = run(true, true, true)
	assert(order == "release", "an already saved flag must not be committed again: " .. order)
	order = run(false, false, true)
	assert(order == "release", "a player who has not claimed the pad must not be marked seen: " .. order)
	order = run(true, false, false)
	assert(order == "release", "no session: nothing but Release: " .. order)
	pass("Bootstrap cleanupPlayer commits an unsaved seen flag before Release (only when the attribute is true and the profile is not)")
end

print(("ALL PASSED (%d checks)"):format(passed))
