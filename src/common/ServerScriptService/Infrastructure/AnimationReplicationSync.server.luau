-- AnimationReplicationSync: owners republish their running animation for a NEW observer.
--
-- Before: every character spawn (every death, in an obby) sent "RepublishCurrent" to ALL
-- players twice; each client then stopped and replayed its track, which replicates to the
-- other N-1 clients. Cost per respawn = 2 * N remotes + 2 * N * (N-1) animation events.
-- With MaxPlayers = 60 that is 120 remotes and ~7,000 animation events per death.
--
-- After: owners only republish when a NEW OBSERVER arrives (a player's first ready
-- character of the session). A respawn of somebody who was already observing needs nothing:
-- their client kept every other Animator's state, and their own new character publishes its
-- own tracks as it starts them. ObserverReady is also rate limited per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animationSync = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpeedsterAnimationSync")

local READY_INTERVAL = 2 -- seconds between ObserverReady reports we listen to, per player
local observing = setmetatable({}, { __mode = "k" }) -- player -> true once they have observed
local readyCharacter = setmetatable({}, { __mode = "k" }) -- player -> last validated character
local lastReadyAt = setmetatable({}, { __mode = "k" })
local syncSerial = 0

local function disableAnimatorLodForCharacter(character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 15)
		local reference = humanoid and (
			humanoid:FindFirstChild("SpeedsterServerAnimatorReference")
				or humanoid:WaitForChild("SpeedsterServerAnimatorReference", 15)
		)
		local animator = reference and reference:IsA("ObjectValue") and reference.Value or nil
		if animator and animator:IsA("Animator") and animator.Parent == humanoid then
			animator.PreferLodEnabled = false
		end
	end)
end

local function bindPlayer(player)
	if player.Character then
		disableAnimatorLodForCharacter(player.Character)
	end
	player.CharacterAdded:Connect(disableAnimatorLodForCharacter)
end
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)

-- Owners republish for one new observer. The observer does not need to republish to itself.
local function republishFor(observer, expectedCharacter)
	if observer.Parent ~= Players or observer.Character ~= expectedCharacter then
		return
	end
	syncSerial += 1
	for _, owner in ipairs(Players:GetPlayers()) do
		if owner ~= observer then
			animationSync:FireClient(owner, "RepublishCurrent", syncSerial)
		end
	end
end

animationSync.OnServerEvent:Connect(function(player, action, reportedCharacter)
	if action ~= "ObserverReady" or typeof(reportedCharacter) ~= "Instance" then
		return
	end
	local now = os.clock()
	if now - (lastReadyAt[player] or -math.huge) < READY_INTERVAL then
		return
	end
	lastReadyAt[player] = now
	if reportedCharacter ~= player.Character
		or not reportedCharacter:IsDescendantOf(workspace)
		or readyCharacter[player] == reportedCharacter
	then
		return
	end

	local humanoid = reportedCharacter:FindFirstChildOfClass("Humanoid")
	local reference = humanoid and humanoid:FindFirstChild("SpeedsterServerAnimatorReference")
	local animator = reference and reference:IsA("ObjectValue") and reference.Value or nil
	if not humanoid
		or not animator
		or not animator:IsA("Animator")
		or animator.Parent ~= humanoid
		or animator:GetAttribute("SpeedsterServerAuthoritative") ~= true
	then
		return
	end
	readyCharacter[player] = reportedCharacter

	if observing[player] then
		return -- a respawn: nobody has to republish anything
	end
	observing[player] = true
	task.delay(0.15, republishFor, player, reportedCharacter)
	task.delay(1.00, republishFor, player, reportedCharacter)
end)

Players.PlayerRemoving:Connect(function(player)
	observing[player] = nil
	readyCharacter[player] = nil
	lastReadyAt[player] = nil
end)

print("[AnimationReplicationSync] join-only republish: 2*(N-1) remotes per JOIN instead of 2*N per RESPAWN.")
