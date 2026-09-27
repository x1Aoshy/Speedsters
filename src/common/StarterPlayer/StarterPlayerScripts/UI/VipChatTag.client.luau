-- UI/VipChatTag.client.luau — the tag in front of every speaker's name in the chat window.
-- 2026-09-26 (owner): the tag is the title the speaker WEARS: the player attribute EquippedTitle
-- that Services/Titles/TitleService publishes from the Titles panel's choice (staff titles like
-- OWNER / DEV included), drawn with the catalog's text and colour (TitleCatalog.ChatPrefix), e.g.
-- <font color="#FFD700"><b>[OWNER]</b></font>. It used to guess [DEV] / [Tester] from the Config
-- staff lists, so an owner who is also a developer always showed [DEV] whatever they picked.
-- "none" shows no tag; with nothing worn, VIP pass owners keep their [VIP] tag. The attribute is
-- read when each message arrives, so a change shows on the next message, for every player.
-- The places use TextChatService (ChatVersion checked 2026-09-26), no legacy chat. This is the
-- only script that sets TextChatService.OnIncomingMessage (it holds one callback).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then return end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TitleCatalog = require(Shared:WaitForChild("TitleCatalog"))
local U4 = require(Shared:WaitForChild("Update4Config"))

local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
if chatInput then
	chatInput.Enabled = true
end

-- The Titles feature switched off (Update4Config / Workspace U4Off_Titles): the old guess from
-- the staff lists, as before Update 4.
local function legacyPrefix(sender: Player?, senderUserId: number): string
	local isDev, isTester, isVip = false, false, false
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
	return tagPrefix
end

local function prefixFor(source: TextSource): string
	local sender = Players:GetPlayerByUserId(source.UserId)
	if not U4.IsOn("Titles") then
		return legacyPrefix(sender, source.UserId)
	end
	if not sender then
		return "" -- left the server: no attributes to read
	end
	return TitleCatalog.ChatPrefix(
		sender:GetAttribute("EquippedTitle"),
		sender:GetAttribute("TitlePreference"),
		sender:GetAttribute("VIPGamepassOwned") == true
	)
end

local function onIncomingMessage(message: TextChatMessage)
	local source = message.TextSource
	if source == nil then
		return nil -- system messages (announcements) keep their own look
	end
	-- A failure here must never cost the message: no tag rather than a broken callback.
	local ok, prefix = pcall(prefixFor, source)
	if not ok or type(prefix) ~= "string" or prefix == "" then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = prefix .. message.PrefixText
	return properties
end

TextChatService.OnIncomingMessage = onIncomingMessage
