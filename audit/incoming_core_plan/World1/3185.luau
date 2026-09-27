local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
if not player then return end

local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
if chatInput then
	chatInput.Enabled = true
end

local function isVip()
	return player:GetAttribute("VIPGamepassOwned") == true
end

local function onIncomingMessage(message)
	if message.TextSource == nil or not isVip() then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = '<font color="#FFD700">[VIP]</font> ' .. message.PrefixText
	return properties
end

TextChatService.OnIncomingMessage = onIncomingMessage

player:GetAttributeChangedSignal("VIPGamepassOwned"):Connect(function()
	-- attribute changes dynamically handled on next message
end)