-- AdminCommands (server)
-- Chat commands for the game owner:
--   /give <PlayerName> <Speed|Wins> <Amount>
--   /speed <PlayerName> <Amount>
--   /wins <PlayerName> <Amount>
-- Amounts are granted exactly (no multipliers) and saved to the DataStore
-- through the same safe save pipeline the rest of the game uses.

local Players = game:GetService("Players")

local ADMIN_USER_ID = 111827288

local function waitForGlobal(name)
	local value = _G[name]
	local waited = 0
	while type(value) ~= "function" and waited < 30 do
		task.wait(0.25)
		waited += 0.25
		value = _G[name]
	end
	return type(value) == "function" and value or nil
end

local grantExactStat = waitForGlobal("SpeedsterGrantExactStat")
local savePlayer = waitForGlobal("SpeedsterSavePlayer")

if not grantExactStat or not savePlayer then
	warn("[AdminCommands] PlayerStats globals were not found; admin commands are disabled.")
	return
end

local function isAdmin(player)
	return player.UserId == ADMIN_USER_ID
end

local function findPlayerByName(name)
	name = string.lower(tostring(name or ""))
	if name == "" then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == name or string.lower(player.DisplayName) == name then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(player.Name), name, 1, true) == 1
			or string.find(string.lower(player.DisplayName), name, 1, true) == 1
		then
			return player
		end
	end

	return nil
end

local function notify(player, text)
	-- Feedback goes to the server output log (visible in Studio and server logs).
	print("[AdminCommands] " .. player.Name .. ": " .. text)
end

local function handleCommand(speaker, message)
	local parts = {}
	for token in string.gmatch(message, "%S+") do
		table.insert(parts, token)
	end

	local command = string.lower(parts[1] or "")

	local statName, targetIndex
	if command == "/give" then
		statName = parts[3]
		targetIndex = 2
	elseif command == "/speed" then
		statName = "Speed"
		targetIndex = 2
	elseif command == "/wins" then
		statName = "Wins"
		targetIndex = 2
	else
		return
	end

	local target = findPlayerByName(parts[targetIndex])
	if not target then
		notify(speaker, "Player not found: " .. tostring(parts[targetIndex]))
		return
	end

	local amount = tonumber(parts[targetIndex + 1])
	if not amount or amount ~= amount or amount == math.huge or amount <= 0 then
		notify(speaker, "Invalid amount: " .. tostring(parts[targetIndex + 1]))
		return
	end

	local ok, granted = grantExactStat(target, statName, amount)
	if ok then
		notify(speaker, string.format("Gave %s %s %s.", target.Name, tostring(granted), statName))
		notify(target, string.format("You received %s %s!", tostring(granted), statName))
		task.defer(savePlayer, target, "admin_grant")
	else
		notify(speaker, "Failed: " .. tostring(granted))
	end
end

-- Legacy chat fallback. Players.PlayerChatted only fires on the client (the
-- server cannot bind it), so hook each player's Chatted event instead. When
-- TextChatService is enabled this rarely fires; the hook below is the real path.
local function hookLegacyChat(player)
	player.Chatted:Connect(function(message)
		if isAdmin(player) then
			handleCommand(player, message)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookLegacyChat(player)
end
Players.PlayerAdded:Connect(hookLegacyChat)

local TextChatService = game:GetService("TextChatService")

-- Hook into all text channels so commands work with TextChatService too.
local okTCS, err = pcall(function()
	TextChatService.ChildAdded:Connect(function(child)
		if child:IsA("TextChannel") then
			child.MessageReceived:Connect(function(textChatMessage)
				local source = textChatMessage.TextSource
				if not source then
					return
				end
				local sender = Players:GetPlayerByUserId(source.UserId)
				if sender and isAdmin(sender) then
					handleCommand(sender, textChatMessage.Text)
				end
			end)
		end
	end)

	for _, child in ipairs(TextChatService:GetChildren()) do
		if child:IsA("TextChannel") then
			child.MessageReceived:Connect(function(textChatMessage)
				local source = textChatMessage.TextSource
				if not source then
					return
				end
				local sender = Players:GetPlayerByUserId(source.UserId)
				if sender and isAdmin(sender) then
					handleCommand(sender, textChatMessage.Text)
				end
			end)
		end
	end
end)

if not okTCS then
	warn("[AdminCommands] Could not hook into TextChatService: " .. tostring(err))
end