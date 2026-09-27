--!strict
-- GlobalAnnouncementService.server.luau
-- Sistema de anuncios globales entre todos los servidores vía MessagingService y comandos de chat /g.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

local MESSAGING_TOPIC = "SpeedsterGlobalAnnouncements_v1"
local DEFAULT_DURATION = 8

-- Lista de UserIds autorizados para enviar anuncios globales
local ALLOWED_USER_IDS: { [number]: boolean } = {
	[5113549114] = true, -- Propietario / Desarrollador principal
}

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage
local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if remote then remote:Destroy() end
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local DisplayRemote = ensureRemote("DisplayGlobalAnnouncement")
local AdminBarRemote = ensureRemote("GlobalAnnouncementRequest")

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if ALLOWED_USER_IDS[player.UserId] == true then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and rank >= 254 then
			return true
		end
	end
	return false
end

local function filterTextForBroadcast(player: Player, rawMessage: string): string
	if RunService:IsStudio() then
		return rawMessage
	end
	local filtered = rawMessage
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(rawMessage, player.UserId)
	end)
	if ok and result then
		local okBroadcast, broadcastText = pcall(function()
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if okBroadcast and broadcastText then
			filtered = broadcastText
		end
	end
	return filtered
end

local function displayLocally(payload: { Message: string, SenderName: string, SenderId: number?, Duration: number? })
	DisplayRemote:FireAllClients(payload)
end

local lastBroadcastAt = 0

local function broadcastAnnouncement(player: Player, rawMessage: string)
	if not isAllowed(player) then
		warn(string.format("[GlobalAnnouncement] %s (UserId: %d) no tiene permisos para anunciar.", player.Name, player.UserId))
		return
	end

	local trimmed = string.match(rawMessage, "^%s*(.-)%s*$") or ""
	if #trimmed == 0 then
		-- Si no escribió mensaje, abrirle la barra interactiva en pantalla
		AdminBarRemote:FireClient(player, "OpenBar")
		return
	end

	if #trimmed > 250 then
		trimmed = string.sub(trimmed, 1, 250)
	end

	local now = os.clock()
	if now - lastBroadcastAt < 1.0 then
		return
	end
	lastBroadcastAt = now

	local filteredMessage = filterTextForBroadcast(player, trimmed)

	local payload = {
		Message = filteredMessage,
		SenderName = player.DisplayName or player.Name,
		SenderId = player.UserId,
		Duration = DEFAULT_DURATION,
		Timestamp = os.time(),
	}

	print(string.format("[GlobalAnnouncement] Transmitiendo anuncio de %s: '%s'", player.Name, filteredMessage))

	-- 1. Mostrar inmediatamente en el servidor local (sin latencia y soporte Studio)
	displayLocally(payload)

	-- 2. Transmitir a todos los demás servidores vía MessagingService
	if not RunService:IsStudio() then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:PublishAsync(MESSAGING_TOPIC, payload)
			end)
			if not ok then
				warn("[GlobalAnnouncement] Fallo al publicar en MessagingService:", err)
			end
		end)
	end
end

-- Suscripción a MessagingService para recibir anuncios de otros servidores
local subscribedOk, subErr = pcall(function()
	MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(message)
		local data = message.Data
		if type(data) == "table" and data.Message then
			-- Evitar duplicar en el servidor que lo originó si tiene el mismo timestamp/sender
			if data.SenderId and data.Timestamp and (os.time() - data.Timestamp < 3) then
				local localSender = Players:GetPlayerByUserId(data.SenderId)
				if localSender then
					return
				end
			end
			displayLocally(data)
		elseif type(data) == "string" then
			displayLocally({
				Message = data,
				SenderName = "Server",
				Duration = DEFAULT_DURATION,
			})
		end
	end)
end)

if not subscribedOk then
	warn("[GlobalAnnouncement] No se pudo suscribir a MessagingService:", subErr)
end

-- Peticiones desde la barra de interfaz gráfica del Admin
AdminBarRemote.OnServerEvent:Connect(function(player, action, messageText)
	if not isAllowed(player) then
		return
	end
	if action == "Broadcast" and type(messageText) == "string" then
		broadcastAnnouncement(player, messageText)
	elseif action == "CheckPermission" then
		AdminBarRemote:FireClient(player, "PermissionGranted")
	end
end)

-- Comandos en el Chat: /g <mensaje>, /global <mensaje>, /announce <mensaje>
local function handleChatCommand(player: Player, text: string)
	if not isAllowed(player) then return end

	local lower = text:lower()
	local commandBody = nil

	if lower:sub(1, 3) == "/g " then
		commandBody = text:sub(4)
	elseif lower == "/g" then
		commandBody = ""
	elseif lower:sub(1, 8) == "/global " then
		commandBody = text:sub(9)
	elseif lower == "/global" then
		commandBody = ""
	elseif lower:sub(1, 10) == "/announce " then
		commandBody = text:sub(11)
	elseif lower == "/announce" then
		commandBody = ""
	elseif lower:sub(1, 8) == "?global " then
		commandBody = text:sub(9)
	end

	if commandBody ~= nil then
		broadcastAnnouncement(player, commandBody)
	end
end

-- Soporte para Legacy Chat (player.Chatted)
local function setupPlayer(player: Player)
	player.Chatted:Connect(function(msg)
		handleChatCommand(player, msg)
	end)

	if isAllowed(player) then
		-- Notificar al cliente que tiene permisos de anuncio
		task.delay(1.5, function()
			if player.Parent then
				AdminBarRemote:FireClient(player, "PermissionGranted")
			end
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

-- Soporte para TextChatService moderno de Roblox
pcall(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local commandsFolder = TextChatService:FindFirstChild("TextChatCommands")
		if not commandsFolder then
			commandsFolder = Instance.new("Folder")
			commandsFolder.Name = "TextChatCommands"
			commandsFolder.Parent = TextChatService
		end

		local function createCommand(name: string, primaryAlias: string, secondaryAlias: string?)
			local cmd = commandsFolder:FindFirstChild(name)
			if not cmd then
				cmd = Instance.new("TextChatCommand")
				cmd.Name = name
				cmd.PrimaryAlias = primaryAlias
				if secondaryAlias then
					cmd.SecondaryAlias = secondaryAlias
				end
				cmd.Parent = commandsFolder
			end
			cmd.Triggered:Connect(function(originTextSource, unfilteredText)
				local player = Players:GetPlayerByUserId(originTextSource.UserId)
				if player then
					local args = string.match(unfilteredText, "^%S+%s*(.*)$") or ""
					broadcastAnnouncement(player, args)
				end
			end)
		end

		createCommand("GlobalAnnounceCommandG", "/g")
		createCommand("GlobalAnnounceCommandGlobal", "/global", "/announce")
	end
end)

print("[GlobalAnnouncementService] ready | MessagingService + Chat Commands (/g) + Admin Bar support active")
