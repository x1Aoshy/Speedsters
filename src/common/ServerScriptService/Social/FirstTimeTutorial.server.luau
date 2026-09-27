         
                                                                               
                                                                              
            
                                                                               
                                                                                
                                                                        

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- 2026-09-21: World 3 is off too. Its treadmill is "Basic" outside the new World 1 map and
-- its pads carry no SafeZoneIndex, so the client had no target there: a new player who joined
-- a friend in World 3 ran an invisible tutorial. The flag now stays false for World 1.
if Config.IsWorld2Place == true or Config.IsWorld3Place == true then
	print("[FirstTimeTutorial] V306HQ inactive outside World 1.")
	return
end

                                                                           
                                 
local FORCE_TUTORIAL_FOR_EVERYONE = false

local STEP_TIMEOUT_SECONDS = 1.7 * 60
local BETWEEN_STEPS_SECONDS = 0.65
local TUTORIAL_WIN_STAGE = Config.IsNewWorld1Map == true and 1 or 2
-- A step's timer waits for the character; this is how often it looks for the root part.
local CHARACTER_POLL_SECONDS = 0.25
-- Waits between save attempts for the seen flag. A failed save leaves the attribute to the
-- profile projection, which writes it back to false on the next profile change.
local SAVE_RETRY_DELAYS = { 2, 5, 10, 20, 40 }
-- Re-offer cap (2026-09-21): an unsaved tutorial is offered again on every join, but not to a
-- player who has rebirthed at least once; they clearly know the train, run, claim loop. Wins
-- and Level are no proof: codes grant Wins, and the day-one daily reward (250 Speed) or the
-- Starter Pack alone lift a new save past Level 10 on the easy first-run curve.
local KNOWN_LOOP_REBIRTHS = 1

local sessions = {}
-- player -> { Connection, Reason, Requested, Saving, Saved }: waits for the first Win pad
-- claim, then keeps saving until _G.SpeedsterSavePlayer reports success. Kept apart from
-- sessions so it outlives the Step 2 timeout.
local seenSaves = {}

local function setAttributeIfChanged(player, name, value)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function disconnectSession(session)
	for _, connection in ipairs(session.Connections) do
		connection:Disconnect()
	end
	table.clear(session.Connections)
end

local function hasCharacterRoot(player)
	local character = player.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local beginStep

local function finishStep(player, session, expectedStep)
	if sessions[player] ~= session
		or session.Active ~= true
		or session.Step ~= expectedStep
	then
		return
	end

	                                                                           
	                                                                     
	session.Token += 1
	session.Step = 0
	setAttributeIfChanged(player, "FirstTimeTutorialStep", 0)
	player:SetAttribute(
		"FirstTimeTutorialTransitionSerial",
		math.max(0, math.floor(tonumber(player:GetAttribute("FirstTimeTutorialTransitionSerial")) or 0)) + 1
	)

	if expectedStep == 1 then
		local transitionToken = session.Token
		task.delay(BETWEEN_STEPS_SECONDS, function()
			if player.Parent == Players
				and sessions[player] == session
				and session.Active == true
				and session.Token == transitionToken
			then
				beginStep(player, session, 2)
			end
		end)
		return
	end

	session.Active = false
	setAttributeIfChanged(player, "FirstTimeTutorialActive", false)
	disconnectSession(session)
	sessions[player] = nil
end

beginStep = function(player, session, step)
	if player.Parent ~= Players or sessions[player] ~= session or session.Active ~= true then
		return
	end

	session.Token += 1
	session.Step = step
	setAttributeIfChanged(player, "FirstTimeTutorialStep", step)

	local timeoutToken = session.Token
	local function stepStillCurrent()
		return player.Parent == Players
			and sessions[player] == session
			and session.Active == true
			and session.Step == step
			and session.Token == timeoutToken
	end
	-- 2026-09-21: the clock starts once the character has a HumanoidRootPart. DataLoaded can
	-- come well before the character on a slow phone (loading screen up to 15 s), and the
	-- player cannot follow an arrow they cannot see yet.
	task.spawn(function()
		while stepStillCurrent() and not hasCharacterRoot(player) do
			task.wait(CHARACTER_POLL_SECONDS)
		end
		if not stepStillCurrent() then
			return
		end
		task.delay(STEP_TIMEOUT_SECONDS, function()
			if stepStillCurrent() then
				finishStep(player, session, step)
			end
		end)
	end)

	                                                                             
	                                                       
	if step == 1 and player:GetAttribute("OnTutorialBrownTreadmill") == true then
		task.defer(finishStep, player, session, 1)
	elseif step == 2 and (tonumber(player:GetAttribute("LastCompletedSafeZone")) or 0) >= TUTORIAL_WIN_STAGE then
		task.defer(finishStep, player, session, 2)
	end
end

local function stopSeenSave(player)
	local pending = seenSaves[player]
	if pending and pending.Connection then
		pending.Connection:Disconnect()
		pending.Connection = nil
	end
	seenSaves[player] = nil
	return pending
end

local function waitForSaveService(player)
	local deadline = os.clock() + 5
	local savePlayer = _G.SpeedsterSavePlayer
	while player.Parent == Players and type(savePlayer) ~= "function" and os.clock() < deadline do
		task.wait(0.05)
		savePlayer = _G.SpeedsterSavePlayer
	end
	if type(savePlayer) ~= "function" then
		return nil
	end
	return savePlayer
end

-- One save attempt. The bridge turns a true attribute into a SetPersistent command and
-- ProfileReducers keeps it true for good. The attribute is set again right before each call
-- because StatsProjection re-projects the profile's value (still false until a save lands) on
-- every profile change.
local function trySaveSeen(player, savePlayer, reason)
	setAttributeIfChanged(player, "FirstTimeTutorialSeen", true)
	local ok, result = pcall(savePlayer, player, reason, true)
	return ok and result == true
end

-- 2026-09-21: the seen flag is saved on completion (or by the re-offer cap), no longer at
-- start, and retried with backoff until a save really lands. If every retry fails the watcher
-- stays connected, so the next pad claim or the player leaving tries again.
local function saveTutorialSeen(player, reason)
	local pending = seenSaves[player]
	if not pending then
		pending = {}
		seenSaves[player] = pending
	end
	pending.Reason = reason
	pending.Requested = true
	setAttributeIfChanged(player, "FirstTimeTutorialSeen", true)
	if pending.Saving or pending.Saved then
		return
	end

	pending.Saving = true
	task.spawn(function()
		local savePlayer = waitForSaveService(player)
		local attempt = 0
		while savePlayer and player.Parent == Players and seenSaves[player] == pending do
			if trySaveSeen(player, savePlayer, pending.Reason) then
				pending.Saved = true
				break
			end
			attempt += 1
			local retryDelay = SAVE_RETRY_DELAYS[attempt]
			if not retryDelay then
				break
			end
			task.wait(retryDelay)
		end
		pending.Saving = false

		if pending.Saved then
			if seenSaves[player] == pending then
				stopSeenSave(player)
			end
		elseif player.Parent == Players then
			warn("[FirstTimeTutorial] Could not save the seen flag for " .. player.Name .. "; retrying on the next claim or on leave")
		end
	end)
end

-- Saved only once the first Win pad is really claimed (Step 2's goal), whenever that happens
-- in this server session, even after Step 2 timed out. A player who leaves, crashes or never
-- noticed the arrow gets the tutorial again on the next join instead of losing it for good.
local function watchFirstWinPadClaim(player)
	stopSeenSave(player)
	local pending = {}
	seenSaves[player] = pending

	local function onClaimChanged()
		if seenSaves[player] == pending
			and (tonumber(player:GetAttribute("LastCompletedSafeZone")) or 0) >= TUTORIAL_WIN_STAGE
		then
			saveTutorialSeen(player, "first_time_tutorial_completed")
		end
	end

	pending.Connection = player:GetAttributeChangedSignal("LastCompletedSafeZone"):Connect(onClaimChanged)
	onClaimChanged()
end

local function startTutorial(player, modeLabel, saveOnCompletion)
	if player.Parent ~= Players or sessions[player] then
		return
	end

	-- FirstTimeTutorialActive goes up right away (before the character exists) so the Update
	-- Logs, Evolve and portal cinematic defer; only the step timers wait for the character.
	player:SetAttribute("FirstTimeTutorialTransitionSerial", 0)
	setAttributeIfChanged(player, "FirstTimeTutorialActive", true)

	local session = {
		Active = true,
		Step = 0,
		Token = 0,
		Connections = {},
	}
	sessions[player] = session

	table.insert(session.Connections, player:GetAttributeChangedSignal("OnTutorialBrownTreadmill"):Connect(function()
		if player:GetAttribute("OnTutorialBrownTreadmill") == true then
			finishStep(player, session, 1)
		end
	end))

	table.insert(session.Connections, player:GetAttributeChangedSignal("LastCompletedSafeZone"):Connect(function()
		if (tonumber(player:GetAttribute("LastCompletedSafeZone")) or 0) >= TUTORIAL_WIN_STAGE then
			finishStep(player, session, 2)
		end
	end))

	if saveOnCompletion then
		watchFirstWinPadClaim(player)
	end
	beginStep(player, session, 1)
	print("[FirstTimeTutorial] V306HQ started for " .. player.Name .. " (" .. modeLabel .. ")")
end

local function setupPlayer(player)
	                                                                              
	                                                                               
	                                                                      
	if FORCE_TUTORIAL_FOR_EVERYONE then
		startTutorial(player, "forced review; completion is not saved", false)
		return
	end

	if player:GetAttribute("DataLoaded") ~= true
		and player:GetAttribute("DataLoadFailed") ~= true
	then
		local readyEvent = Instance.new("BindableEvent")
		local readySignaled = false
		local loadedConnection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") == true then
				readySignaled = true
				readyEvent:Fire()
			end
		end)
		local failedConnection = player:GetAttributeChangedSignal("DataLoadFailed"):Connect(function()
			if player:GetAttribute("DataLoadFailed") == true then
				readySignaled = true
				readyEvent:Fire()
			end
		end)
		local ancestryConnection = player.AncestryChanged:Connect(function()
			if player.Parent ~= Players then
				readySignaled = true
				readyEvent:Fire()
			end
		end)

		while not readySignaled
			and player.Parent == Players
			and player:GetAttribute("DataLoaded") ~= true
			and player:GetAttribute("DataLoadFailed") ~= true
		do
			readyEvent.Event:Wait()
		end

		loadedConnection:Disconnect()
		failedConnection:Disconnect()
		ancestryConnection:Disconnect()
		readyEvent:Destroy()
	end

	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return
	end

	                                                                         
	                                                                           
	                                     
	local isMemoryOnlyStudioPreview = RunService:IsStudio()
		and player:GetAttribute("SessionDataOnly") == true
	if player:GetAttribute("FirstTimeTutorialSeen") == true then
		setAttributeIfChanged(player, "FirstTimeTutorialActive", false)
		setAttributeIfChanged(player, "FirstTimeTutorialStep", 0)
		return
	end

	-- The re-offer cap (see KNOWN_LOOP_REBIRTHS): marked seen silently, nothing is shown.
	if (tonumber(player:GetAttribute("Rebirths")) or 0) >= KNOWN_LOOP_REBIRTHS then
		setAttributeIfChanged(player, "FirstTimeTutorialActive", false)
		setAttributeIfChanged(player, "FirstTimeTutorialStep", 0)
		saveTutorialSeen(player, "first_time_tutorial_known_loop")
		return
	end

	startTutorial(
		player,
		isMemoryOnlyStudioPreview and "memory-only Studio preview" or "new save",
		true
	)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(setupPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		session.Active = false
		session.Token += 1
		disconnectSession(session)
		sessions[player] = nil
	end

	-- A claim whose save never landed gets one last try while the profile is still open.
	local pending = stopSeenSave(player)
	if pending and pending.Requested and not pending.Saved then
		task.spawn(function()
			local savePlayer = _G.SpeedsterSavePlayer
			if type(savePlayer) ~= "function" or not trySaveSeen(player, savePlayer, pending.Reason) then
				warn("[FirstTimeTutorial] Seen flag still unsaved for " .. player.Name .. " on leave; offered again next join")
			end
		end)
	end
end)

print("[FirstTimeTutorial] V306KBV ready | offered until the first Win pad claim | Stage 1 Win pad completes Step 2 | seen flag saved on that claim (or Rebirths >= 1)")
