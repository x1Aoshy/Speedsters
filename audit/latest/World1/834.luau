local Players = game:GetService("Players")

local ADMIN_USER_ID = 111827288

local function waitForGlobal(name)
	local value = _G[name]
	while type(value) ~= "function" do
		task.wait(0.5)
		value = _G[name]
	end
	return value
end

local grantExactStat = waitForGlobal("SpeedsterGrantExactStat")
local addRebirths = waitForGlobal("SpeedsterAddRebirths")
local savePlayer = waitForGlobal("SpeedsterSavePlayer")

local function findTarget(name)
	name = string.lower(name)

	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == name or string.lower(player.DisplayName) == name then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(player.Name), name, 1, true)
			or string.find(string.lower(player.DisplayName), name, 1, true)
		then
			return player
		end
	end

	return nil
end

local function notify(admin, message)
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Admin Give",
		Text = message,
		Duration = 4,
	})
end

local commands = {
	givespeed = function(admin, target, amount)
		local ok, result = grantExactStat(target, "Speed", amount)
		if ok then
			notify(admin, "Gave " .. tostring(result) .. " Speed to " .. target.Name)
		else
			notify(admin, "Failed: " .. tostring(result))
		end
	end,
	givewins = function(admin, target, amount)
		local ok, result = grantExactStat(target, "Wins", amount)
		if ok then
			notify(admin, "Gave " .. tostring(result) .. " Wins to " .. target.Name)
		else
			notify(admin, "Failed: " .. tostring(result))
		end
	end,
	giverebirths = function(admin, target, amount)
		addRebirths(target, math.floor(amount))
		notify(admin, "Gave " .. tostring(math.floor(amount)) .. " Rebirths to " .. target.Name)
	end,
}

local function onChatted(player, message)
	if player.UserId ~= ADMIN_USER_ID then
		return
	end

	if string.sub(message, 1, 1) ~= "/" then
		return
	end

	local parts = {}
	for token in string.gmatch(message, "%S+") do
		table.insert(parts, string.lower(token))
	end

	local commandName = string.gsub(parts[1] or "", "/", "")
	local command = commands[commandName]
	if not command then
		return
	end

	local target = findTarget(parts[2] or "")
	if not target then
		notify(player, "Player not found: " .. tostring(parts[2]))
		return
	end

	local amount = tonumber(parts[3])
	if not amount or amount <= 0 or amount ~= amount or amount == math.huge then
		notify(player, "Invalid amount: " .. tostring(parts[3]))
		return
	end

	command(player, target, amount)
	task.defer(savePlayer, target, "admin_give")
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end