         
                                                                               
                                                                              
            
                                                                               
                                                                                
                                                                        

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if Config.IsWorld2Place == true then
	print("[FirstTimeTutorial] V306HQ inactive in World 2.")
	return
end

                                                                           
                                 
local FORCE_TUTORIAL_FOR_EVERYONE = false

local STEP_TIMEOUT_SECONDS = 1.7 * 60
local BETWEEN_STEPS_SECONDS = 0.65
local TUTORIAL_WIN_STAGE = Config.IsNewWorld1Map == true and 1 or 2

local sessions = {}

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
	task.delay(STEP_TIMEOUT_SECONDS, function()
		if player.Parent == Players
			and sessions[player] == session
			and session.Active == true
			and session.Step == step
			and session.Token == timeoutToken
		then
			finishStep(player, session, step)
		end
	end)

	                                                                             
	                                                       
	if step == 1 and player:GetAttribute("OnTutorialBrownTreadmill") == true then
		task.defer(finishStep, player, session, 1)
	elseif step == 2 and tonumber(player:GetAttribute("LastCompletedSafeZone")) == TUTORIAL_WIN_STAGE then
		task.defer(finishStep, player, session, 2)
	end
end

local function saveTutorialStarted(player)
	                                                                             
	                                                                            
	                                                                     
	task.spawn(function()
		local deadline = os.clock() + 5
		local savePlayer = _G.SpeedsterSavePlayer
		while player.Parent == Players and type(savePlayer) ~= "function" and os.clock() < deadline do
			task.wait(0.05)
			savePlayer = _G.SpeedsterSavePlayer
		end
		if type(savePlayer) ~= "function" then
			warn("[FirstTimeTutorial] Save service was unavailable for " .. player.Name)
			return
		end

		local ok, result = pcall(savePlayer, player, "first_time_tutorial_started", true)
		if not ok or result ~= true then
			warn("[FirstTimeTutorial] Could not save first-visit flag for " .. player.Name)
		end
	end)
end

local function startTutorial(player, modeLabel, markAndSaveSeen)
	if player.Parent ~= Players or sessions[player] then
		return
	end

	                                                                            
	                                                                               
	if markAndSaveSeen then
		player:SetAttribute("FirstTimeTutorialSeen", true)
	end

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
		if tonumber(player:GetAttribute("LastCompletedSafeZone")) == TUTORIAL_WIN_STAGE then
			finishStep(player, session, 2)
		end
	end))

	if markAndSaveSeen then
		saveTutorialStarted(player)
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
end)

print("[FirstTimeTutorial] V306KBV ready | one-time-ever tutorial | Stage 1 Win pad completes Step 2 | seen flag flushed at start")
