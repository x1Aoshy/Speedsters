--!strict
-- ChatBoostCommands.luau
-- Permite a los administradores autorizados (Gekkoh, Owner, Admins) activar Server Boosts
-- usando comandos en el chat con barra "/":
--   /active * 2 Speed 30
--   /active * 2 Win 30
--   /active 2 speed 30
--   /active 2 win 30
--   /active 2x speed 30
--   /active speed 30
--   /active win 30
--   /boost speed 30
--   /boost win 30
--
-- Al activarse:
-- 1. Emite un anuncio en el chat: "⚡ [SERVER BOOST] Gekkoh has activated 2x Speed for 30 minutes!"
-- 2. Emite un anuncio en pantalla global (DisplayGlobalAnnouncement)
-- 3. Aplica el multiplicador real en el servidor para todos los jugadores mediante PotionServer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))

local ADMIN_USER_IDS: { [number]: boolean } = {
	[111827288] = true, -- Gekkoh / Owner
	[767108248] = true, -- Admin
}

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ADMIN_USER_IDS[player.UserId] == true then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local function broadcastSystemChatMessage(text: string)
	-- Modern TextChatService
	pcall(function()
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		if textChannels then
			local rbxGeneral = textChannels:FindFirstChild("RBXGeneral")
			if rbxGeneral and rbxGeneral:IsA("TextChannel") then
				rbxGeneral:DisplaySystemMessage(text)
			end
		end
	end)
end

local function broadcastScreenAnnouncement(sender: Player, message: string)
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local displayRemote = remotes and remotes:FindFirstChild("DisplayGlobalAnnouncement")
		if displayRemote and displayRemote:IsA("RemoteEvent") then
			displayRemote:FireAllClients({
				Message = message,
				SenderName = sender.DisplayName or sender.Name,
				SenderId = sender.UserId,
				Duration = 10,
			})
		end
	end)
end

local function parseCommand(rawMessage: string): (string?, number?, number?)
	local msg = string.lower(rawMessage)
	if msg:sub(1, 1) == "/" then
		msg = msg:sub(2)
	else
		return nil, nil, nil
	end

	local isCommand = false
	if msg:match("^active") or msg:match("^boost") or msg:match("^2x") or msg:match("^speed2x") or msg:match("^win2x") then
		isCommand = true
	end
	if not isCommand then
		return nil, nil, nil
	end

	local boostType: string? = nil
	if msg:find("speed") or msg:find("vel") then
		boostType = "Speed"
	elseif msg:find("win") or msg:find("vic") or msg:find("victoria") then
		boostType = "Wins"
	elseif msg:find("all") or msg:find("todo") then
		boostType = "All"
	else
		boostType = "Speed"
	end

	local mult = 2
	local foundMult = msg:match("%*%s*(%d+)") or msg:match("(%d+)%s*x") or msg:match("x%s*(%d+)")
	if foundMult then
		mult = tonumber(foundMult) or 2
	end

	local minutes = 30
	local foundMin = msg:match("(%d+)%s*m") or msg:match("(%d+)%s*min")
	if foundMin then
		minutes = tonumber(foundMin) or 30
	else
		local numbers = {}
		for token in msg:gmatch("%d+") do
			table.insert(numbers, tonumber(token))
		end
		if #numbers >= 2 then
			if numbers[1] <= 10 and numbers[2] > 10 then
				mult = numbers[1]
				minutes = numbers[2]
			elseif numbers[2] <= 10 and numbers[1] > 10 then
				minutes = numbers[1]
				mult = numbers[2]
			else
				mult = numbers[1]
				minutes = numbers[2]
			end
		elseif #numbers == 1 then
			if numbers[1] > 10 then
				minutes = numbers[1]
			else
				mult = numbers[1]
			end
		end
	end

	mult = math.clamp(mult, 2, 100)
	minutes = math.clamp(minutes, 1, 240)

	return boostType, mult, minutes
end

local function executeBoost(speaker: Player, boostType: string, mult: number, minutes: number)
	local speakerName = speaker.DisplayName or speaker.Name
	local durationSec = minutes * 60

	if boostType == "Speed" or boostType == "All" then
		local grant = PotionServer.GrantServerBoost(minutes, mult, speakerName)
		if grant and grant.Notify then
			grant.Notify()
		end
	end

	if boostType == "Wins" or boostType == "All" then
		local newExpire = os.time() + durationSec
		Workspace:SetAttribute("ServerWinsBoostExpiresUnix", newExpire)
		Workspace:SetAttribute("ServerWinsBoostMultiplier", mult)

		for _, p in ipairs(Players:GetPlayers()) do
			pcall(function()
				local winGrant = PotionServer.GrantWinsPotion(p, minutes, mult)
				if winGrant and winGrant.Notify then
					winGrant.Notify()
				end
			end)
		end
	end

	local typeLabel = if boostType == "All" then "Speed & Wins" else boostType
	local icon = if boostType == "Wins" then "🏆" else "⚡"
	local chatAnnouncement = string.format("<font color='#FFD700'><b>%s [SERVER BOOST] %s has activated %dx %s for %d minutes!</b></font>", icon, speakerName, mult, typeLabel, minutes)
	local screenAnnouncement = string.format("🚀 %s has activated %dx %s for %d minutes!", speakerName, mult, typeLabel, minutes)

	broadcastSystemChatMessage(chatAnnouncement)
	broadcastScreenAnnouncement(speaker, screenAnnouncement)

	print(string.format("[ChatBoostCommands] %s executed /active %s %dx for %dm", speaker.Name, typeLabel, mult, minutes))
end

local function onMessage(speaker: Player, message: string)
	if not isAllowed(speaker) then
		return
	end

	local boostType, mult, minutes = parseCommand(message)
	if boostType and mult and minutes then
		executeBoost(speaker, boostType, mult, minutes)
	end
end

local function setupPlayer(player: Player)
	player.Chatted:Connect(function(msg)
		onMessage(player, msg)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

pcall(function()
	TextChatService.MessageReceived:Connect(function(textChatMessage)
		local source = textChatMessage.TextSource
		if not source then return end
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			onMessage(player, textChatMessage.Text)
		end
	end)
end)

print("[ChatBoostCommands] Loaded successfully. Slash commands active for authorized admins.")
