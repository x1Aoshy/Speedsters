local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then return end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
if chatInput then
	chatInput.Enabled = true
end

local function onIncomingMessage(message)
	if message.TextSource == nil then
		return nil
	end

	local senderUserId = message.TextSource.UserId
	local sender = Players:GetPlayerByUserId(senderUserId)

	local isDev = false
	local isTester = false
	local isVip = false

	if sender then
		isDev = Config.IsDeveloper(sender)
		isTester = Config.IsTester(sender)
		isVip = sender:GetAttribute("VIPGamepassOwned") == true
	else
		isDev = Config.Developers[senderUserId] == true
		isTester = Config.Testers[senderUserId] == true
	end

	local tagPrefix = ""
	if isDev then
		tagPrefix ..= '<font color="#FF4500"><b>[DEV]</b></font> '
	elseif isTester then
		tagPrefix ..= '<font color="#00E5FF"><b>[Tester]</b></font> '
	end

	if isVip then
		tagPrefix ..= '<font color="#FFD700"><b>[VIP]</b></font> '
	end

	if tagPrefix ~= "" then
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = tagPrefix .. message.PrefixText
		return properties
	end

	return nil
end

TextChatService.OnIncomingMessage = onIncomingMessage