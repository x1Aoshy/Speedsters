--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Validation = require(ServerScriptService.Admin.AdminRequestValidation)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)
local acceptEvent = Validation.NewEventCache()

local MESSAGING_TOPIC = "SpeedsterGlobalAnnouncements_v1"
local DEFAULT_DURATION = 8

local ALLOWED_USER_IDS: { [number]: boolean } = {
	[767108248] = true,
}

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
	if RunService:IsStudio() then return true end
	if ALLOWED_USER_IDS[player.UserId] == true then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local function filterTextForBroadcast(player: Player, rawMessage: string): string?
	return Validation.FilterBroadcast(TextService, player.UserId, rawMessage)
end

local function displayLocally(payload: { Message: string, SenderName: string, SenderId: number?, Duration: number? })
	DisplayRemote:FireAllClients(payload)
end

local lastBroadcastAt = 0

local function broadcastAnnouncement(player: Player, rawMessage: string)
	if type(rawMessage)~="string" or #rawMessage>512 or not RateLimiter.Allow(player,"AnnouncementBroadcast",1) then return end
	if not isAllowed(player) then return end

	local trimmed = string.match(rawMessage, "^%s*(.-)%s*$") or ""
	if #trimmed == 0 then
		AdminBarRemote:FireClient(player, "OpenBar")
		return
	end

	if #trimmed > 250 then trimmed = string.sub(trimmed, 1, 250) end

	local now = os.clock()
	if now - lastBroadcastAt < 1.0 then return end
	lastBroadcastAt = now

	local filteredMessage = filterTextForBroadcast(player, trimmed)
	if not filteredMessage then return end

	local payload = {
		Message = filteredMessage,
		EventId = HttpService:GenerateGUID(false),
		OriginJobId = game.JobId,
		SenderName = player.DisplayName or player.Name,
		SenderId = player.UserId,
		Duration = DEFAULT_DURATION,
		Timestamp = os.time(),
	}

	acceptEvent(payload.EventId, os.time())
	displayLocally(payload)

	if not RunService:IsStudio() then
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(MESSAGING_TOPIC, payload)
			end)
		end)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(message)
		local data = message and message.Data
		if not Validation.Payload(data) or type(data.Message)~="string" or #data.Message==0
			or type(data.SenderName)~="string" or not Validation.Finite(data.Timestamp)
			or math.abs(os.time()-data.Timestamp)>600 or data.OriginJobId==game.JobId then return end
		if not acceptEvent(data.EventId,os.time()) then return end
		displayLocally({Message=data.Message,SenderName=data.SenderName,SenderId=data.SenderId,
			Duration=math.clamp(tonumber(data.Duration) or DEFAULT_DURATION,1,30)})

	end)
end)

AdminBarRemote.OnServerEvent:Connect(function(player, action, messageText)
	if not RateLimiter.Allow(player,"AnnouncementRequest",0.25) then return end
	if not isAllowed(player) then return end
	if action == "Broadcast" and type(messageText) == "string" then
		broadcastAnnouncement(player, messageText)
	elseif action == "CheckPermission" then
		AdminBarRemote:FireClient(player, "PermissionGranted")
	end
end)

local function handleChatCommand(player: Player, text: string)
	if not isAllowed(player) then return end
	local lower = text:lower()
	local commandBody = nil
	if lower:sub(1, 3) == "/g " then commandBody = text:sub(4)
	elseif lower == "/g" then commandBody = ""
	elseif lower:sub(1, 8) == "/global " then commandBody = text:sub(9)
	elseif lower == "/global" then commandBody = ""
	elseif lower:sub(1, 10) == "/announce " then commandBody = text:sub(11)
	elseif lower == "/announce" then commandBody = ""
	end

	if commandBody ~= nil then
		broadcastAnnouncement(player, commandBody)
	end
end

local function setupPlayer(player: Player)
	player.Chatted:Connect(function(msg) handleChatCommand(player, msg) end)
	if isAllowed(player) then
		task.delay(1.5, function()
			if player.Parent then AdminBarRemote:FireClient(player, "PermissionGranted") end
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)

pcall(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local commandsFolder = TextChatService:FindFirstChild("TextChatCommands") or Instance.new("Folder", TextChatService)
		commandsFolder.Name = "TextChatCommands"
		local cmd = Instance.new("TextChatCommand", commandsFolder)
		cmd.Name = "GlobalAnnounceG"
		cmd.PrimaryAlias = "/g"
		cmd.SecondaryAlias = "/announce"
		cmd.Triggered:Connect(function(source, text)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				local args = string.match(text, "^%S+%s*(.*)$") or ""
				broadcastAnnouncement(player, args)
			end
		end)
	end
end)
