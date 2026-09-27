-- CommunityRewardService.server.luau (Update 4, 2026-09-25)
-- The Community reward (the designer's "Community rewards" panel, UI/CommunityRewardsController):
-- a Member title, a 30 minute 2x Speed potion and 3 Spin Wheel tickets, once per account.
--
-- Two ways to earn it, chosen by the player's policy (PolicyService), never by the client:
--   Discord allowed   the code from our Discord server (/getcode), typed in the panel or in the
--                     normal Codes window (CodesSystem hands unknown codes to
--                     _G.SpeedsterRedeemCommunityCode). No URL or invite is ever sent: the
--                     link lives on the game page.
--   Discord refused   (or the policy has not answered yet, or failed) the word "Discord" never
--                     reaches the player: they join our Roblox group and the server checks the
--                     membership before paying. Codes are refused for them.
-- Valid codes: U4.Community.Codes, or the list the owner sets from the admin panel
-- (DataStore U4.Community.CodeStoreName / CodeStoreKey = { Codes = {...}, At }), cached 5 min.
-- At most U4.Community.MaxWrongPerMinute wrong codes a minute per player, on either path.
-- One Commit pays everything under the operation id "u4community:v1", and
-- CommunitySection refuses a second Claim, so the reward can never be paid twice.
--
-- Remotes: CommunityRewardRequest ("Get" | "Redeem", code | "VerifyGroup", "Joined"?), RemoteGuard
-- 1 s; CommunityRewardUpdate { DiscordAllowed, Claimed, GroupId, Success?, Message?, Reason?, Rewards }.
-- Player attributes: CommunityDiscordAllowed, CommunityRewardClaimed.
--
-- 2026-09-26 (owner: "the community reward doesn't come out / work"), found in this flow:
--   * the membership check trusted Player:IsInGroupAsync, whose answer Roblox caches for the
--     session: the first check (a Redeem tapped before joining, or, in a group-owned place,
--     TitleSystem's GetRankInGroupAsync(game.CreatorId) at every join) fixed "not a member" for
--     the rest of the session, so a player who then joined from the panel's prompt was never
--     paid. A "no" is now re-read from GroupService:GetGroupsAsync (the web list), and a
--     VerifyGroup sent right after the prompt said Joined ("Joined") re-reads it for a few seconds;
--   * a request inside RemoteGuard's second (or while a check was running) was dropped with no
--     answer: it is answered now (RemoteGuard's onDropped runs it once the guard allows);
--   * the answers carry a Reason the panel shows in the player's language (Message stays, in
--     English, for the Codes window).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local CodesCatalog = require(Shared:WaitForChild("Catalogs"):WaitForChild("CodesCatalog"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local RemoteGuard = require(Services:WaitForChild("RemoteGuard"))
-- The dispatcher tells whether TitlesSection is built: a U4.Titles.Grant it cannot route would
-- refuse the whole reward, so the title is only asked for when its section is there.
local Update4Profile = (function()
	local ok, api = pcall(function()
		return require(Services:WaitForChild("Data"):WaitForChild("Update4Profile", 10))
	end)
	return if ok and type(api) == "table" then api else nil
end)()
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end
local Request = ensureRemote("CommunityRewardRequest")
local Update = ensureRemote("CommunityRewardUpdate")
local TemporaryBoostUpdate = ensureRemote("TemporaryBoostUpdate")

local SETTINGS = U4.Community
local OPERATION_ID = "u4community:v1"
local TITLE_ID = tostring(SETTINGS.TitleId or "member")
local WRONG_WINDOW = 60
local MAX_CODE_LENGTH = 64

local discordAllowed: { [Player]: boolean } = {}
local wrongAt: { [Player]: { number } } = {}
local busy: { [Player]: boolean } = {}
-- A Commit that answered Pending was applied in memory; its retry answers AlreadyCommitted,
-- which is then this player's own payment, not an earlier one (2026-09-25 review).
local pendingPaid: { [Player]: boolean } = {}

local function rewards()
	return {
		SpeedPotionMinutes = tonumber(SETTINGS.SpeedPotionMinutes) or 30,
		SpinTickets = tonumber(SETTINGS.SpinTickets) or 3,
		TitleId = TITLE_ID,
	}
end

local function isClaimed(player: Player): boolean
	return player:GetAttribute("CommunityRewardClaimed") == true
end

-- 2026-09-26: every answer is a Reason (the panel's own texts, en/es/pt) and this English line
-- (the Codes window's message, and the panel's fallback).
local MESSAGES = {
	AlreadyClaimed = "You already claimed the Community reward.",
	Loading = "Your data is still loading. Try again.",
	Pending = "Your reward is awaiting save confirmation. Try again shortly.",
	Failed = "The reward could not be given. Try again later.",
	Busy = "Please wait...",
	InvalidCode = "Invalid code.",
	TooMany = "Too many tries. Wait a minute and try again.",
	TooManyCodes = "Too many wrong codes. Wait a minute and try again.",
	Off = "The Community reward is not available right now.",
	UseCode = "Enter the code and tap Redeem.",
	NotMember = "Join our Roblox group first, then tap Redeem.",
}
local function messageFor(reason: string): string
	if reason == "Success" then
		local reward = rewards()
		return string.format("Community reward! 2x Speed for %d minutes, %d Spins and the Member title!",
			reward.SpeedPotionMinutes, reward.SpinTickets)
	end
	return MESSAGES[reason] or MESSAGES.Failed
end
-- The panel's Reason for an answer (TooManyCodes is TooMany there).
local function panelReason(reason: string?): string?
	return if reason == "TooManyCodes" then "TooMany" else reason
end

local function send(player: Player, success: boolean?, reason: string?)
	if player.Parent ~= Players then
		return
	end
	Update:FireClient(player, {
		DiscordAllowed = discordAllowed[player] == true,
		Claimed = isClaimed(player),
		GroupId = tonumber(SETTINGS.GroupId) or 0,
		Success = success,
		Message = if reason then messageFor(reason) else nil,
		Reason = panelReason(reason),
		Rewards = rewards(),
		Enabled = U4.IsOn("Community"),
	})
end

----------------------------------------------------------------------
-- Policy: Discord may be named only when PolicyService says so. Until it answers (and on any
-- failure) the player is on the group path: hiding Discord for a moment is safe, showing it
-- to a player who may not see it is not.
----------------------------------------------------------------------
local function lookUpPolicy(player: Player)
	discordAllowed[player] = false
	player:SetAttribute("CommunityDiscordAllowed", false)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if player.Parent ~= Players then
		return
	end
	local allowed = false
	if ok and type(info) == "table" and type(info.AllowedExternalLinkReferences) == "table" then
		allowed = table.find(info.AllowedExternalLinkReferences, "Discord") ~= nil
	elseif not ok and RunService:IsStudio() then
		-- Studio test accounts often have no policy to read.
		allowed = true
	end
	discordAllowed[player] = allowed
	player:SetAttribute("CommunityDiscordAllowed", allowed)
	send(player, nil, nil)
end

----------------------------------------------------------------------
-- Codes
----------------------------------------------------------------------
local configCodes: { [string]: boolean } = {}
for _, code in SETTINGS.Codes or {} do
	local key = CodesCatalog.Normalize(code)
	if key ~= "" then
		configCodes[key] = true
	end
end

local storeCodes: { [string]: boolean } = {}
-- 2026-09-25 (final fix): once the admin panel has saved a code list, only that list is valid:
-- the Update4Config codes are the fallback for an empty (or never readable) store, so rotating
-- the code from the panel retires a leaked one. A failed read keeps the last good list.
local storeHasList = false
local storeReadAt = -math.huge
local storeReading = false
local CACHE_SECONDS = tonumber(SETTINGS.CodeCacheSeconds) or 300

local function readStoreCodes()
	if os.clock() - storeReadAt < CACHE_SECONDS then
		return
	end
	if storeReading then
		-- Another request is reading already: wait for it (briefly) instead of reading twice.
		local deadline = os.clock() + 5
		while storeReading and os.clock() < deadline do
			task.wait(0.1)
		end
		return
	end
	storeReading = true
	local ok, value = pcall(function()
		local store = game:GetService("DataStoreService"):GetDataStore(SETTINGS.CodeStoreName)
		return store:GetAsync(SETTINGS.CodeStoreKey)
	end)
	storeReading = false
	storeReadAt = os.clock()
	if not ok then
		-- Studio without API access refuses every DataStore call; that is not worth a warning.
		if not RunService:IsStudio() then
			warn("[CommunityRewardService] Could not read the community code list: " .. tostring(value))
		end
		return
	end
	local fresh = {}
	if type(value) == "table" and type(value.Codes) == "table" then
		for index, code in value.Codes do
			if type(index) == "number" and index <= 20 then
				local key = CodesCatalog.Normalize(code)
				if key ~= "" then
					fresh[key] = true
				end
			end
		end
	end
	storeCodes = fresh
	storeHasList = next(fresh) ~= nil
end

local function isCommunityCode(code: any): boolean
	local key = CodesCatalog.Normalize(code)
	if key == "" then
		return false
	end
	readStoreCodes()
	if storeHasList then
		return storeCodes[key] == true
	end
	return configCodes[key] == true
end

-- The admin panel's SetCommunityCode drops the cache so this server takes the new code now.
_G.SpeedsterForgetCommunityCodes = function()
	storeReadAt = -math.huge
end

local function wrongCount(player: Player): number
	local now = os.clock()
	local list = wrongAt[player] or {}
	local kept = {}
	for _, at in list do
		if now - at < WRONG_WINDOW then
			table.insert(kept, at)
		end
	end
	wrongAt[player] = kept
	return #kept
end

local function tooManyWrong(player: Player): boolean
	return wrongCount(player) >= (tonumber(SETTINGS.MaxWrongPerMinute) or 5)
end

local function noteWrong(player: Player)
	wrongCount(player)
	table.insert(wrongAt[player], os.clock())
end

----------------------------------------------------------------------
-- The reward
----------------------------------------------------------------------
local function profileOf(player: Player): any
	local handle = DataService.GetHandle(player.UserId)
	local view = handle and DataService.Inspect(handle)
	return if view and view.ok and view.value then view.value.profile else nil
end

local function savedClaim(profile: any): boolean
	local u4 = type(profile) == "table" and profile.U4
	local section = type(u4) == "table" and u4.Community
	return type(section) == "table" and section.Claimed == true
end

local function ownsTitle(profile: any): boolean
	local u4 = type(profile) == "table" and profile.U4
	local titles = type(u4) == "table" and u4.Titles
	local owned = type(titles) == "table" and titles.Owned
	return type(owned) == "table" and table.find(owned, TITLE_ID) ~= nil
end

local function markClaimed(player: Player)
	player:SetAttribute("CommunityRewardClaimed", true)
end

-- Pays the reward (one Commit). Returns ok, reason (MESSAGES' key, or "Success").
local function claim(player: Player): (boolean, string)
	if player:GetAttribute("DataLoaded") ~= true then
		return false, "Loading"
	end
	if isClaimed(player) and not pendingPaid[player] then
		return false, "AlreadyClaimed"
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false, "Loading"
	end
	local profile = profileOf(player)
	if savedClaim(profile) and not pendingPaid[player] then
		markClaimed(player)
		return false, "AlreadyClaimed"
	end
	local reward = rewards()
	local commands: { any } = { { kind = "U4.Community.Claim", at = os.time() } }
	if Update4Profile and Update4Profile.HasSection("Titles") and not ownsTitle(profile) then
		table.insert(commands, { kind = "U4.Titles.Grant", id = TITLE_ID })
	end
	table.insert(commands, {
		kind = "GrantBuff",
		grant = { kind = "SpeedPotion", addedSeconds = reward.SpeedPotionMinutes * 60, multiplier = 2, bottleType = "Small" },
	})
	table.insert(commands, { kind = "GrantSpinTickets", amount = reward.SpinTickets })
	local ok, result = pcall(DataService.Commit, handle, {
		operationId = OPERATION_ID,
		fingerprint = OPERATION_ID,
		commands = commands,
	})
	if not ok or type(result) ~= "table" then
		return false, "Pending"
	end
	if result.kind == "AlreadyCommitted" then
		-- Paid before (this is a retry of that same transaction): nothing is granted again.
		markClaimed(player)
		if not pendingPaid[player] then
			return false, "AlreadyClaimed"
		end
		-- ...but when that earlier try was this session's Pending one, the player has never
		-- been told: finish it as the claim it is (nothing is granted twice either way).
		pendingPaid[player] = nil
	elseif result.kind == "Pending" then
		pendingPaid[player] = true
		return false, "Pending"
	elseif result.kind == "Rejected" then
		local message = type(result.error) == "table" and tostring(result.error.message) or ""
		if string.find(message, "already claimed", 1, true) then
			markClaimed(player)
			if not pendingPaid[player] then
				return false, "AlreadyClaimed"
			end
			pendingPaid[player] = nil
		else
			warn("[CommunityRewardService] The reward was refused: " .. message)
			return false, "Failed"
		end
	elseif result.kind ~= "Committed" then
		return false, "Pending"
	end
	markClaimed(player)
	FunnelAnalytics.Step(player, "Community_Reward", 3)
	local titles = (_G :: any).SpeedsterTitles
	if type(titles) == "table" and type(titles.Refresh) == "function" then
		pcall(titles.Refresh, player)
	end
	if type(_G.SpeedsterRefreshSpinWheel) == "function" then
		pcall(_G.SpeedsterRefreshSpinWheel, player)
	end
	local text = messageFor("Success")
	pcall(function()
		TemporaryBoostUpdate:FireClient(player, { Type = "SpeedPotion", Message = text })
	end)
	return true, "Success"
end

-- One redeem at a time per player, whichever door it came through.
local function exclusive(player: Player, work: () -> (boolean, string)): (boolean, string)
	if busy[player] then
		return false, "Busy"
	end
	busy[player] = true
	local ok, granted, reason = pcall(work)
	busy[player] = nil
	if not ok then
		warn("[CommunityRewardService] " .. tostring(granted))
		return false, "Failed"
	end
	return granted, reason
end

local function redeemCode(player: Player, code: any): (boolean, string)
	if not U4.IsOn("Community") then
		return false, "InvalidCode"
	end
	if type(code) ~= "string" or #code > MAX_CODE_LENGTH then
		return false, "InvalidCode"
	end
	if discordAllowed[player] ~= true then
		-- A player who may not be told about Discord cannot have its code either; the message
		-- is the plain one any unknown code gets.
		return false, "InvalidCode"
	end
	if tooManyWrong(player) then
		return false, "TooManyCodes"
	end
	if not isCommunityCode(code) then
		noteWrong(player)
		return false, "InvalidCode"
	end
	return exclusive(player, function()
		return claim(player)
	end)
end

-- 2026-09-26: after the panel's prompt said Joined, the web list may lag a moment behind.
local JOIN_RECHECK_SECONDS = { 1.5, 3 }

-- The web list of the player's groups (GroupService:GetGroupsAsync): read fresh, where the
-- Player methods answer from the session's cache.
local function listedInGroup(player: Player, groupId: number): boolean
	local listed, groups = pcall(function()
		return game:GetService("GroupService"):GetGroupsAsync(player.UserId)
	end)
	if listed and type(groups) == "table" then
		for _, group in groups do
			if type(group) == "table" and tonumber(group.Id) == groupId then
				return true
			end
		end
	end
	return false
end

-- 2026-09-26 (owner: the reward never came out): a "yes" from IsInGroupAsync is final; a "no"
-- (or an error) may be its session cache, filled at the join, before the panel's prompt: the
-- web list decides, re-read for a few seconds when the prompt has just said Joined.
local function inGroup(player: Player, justJoined: boolean?): boolean
	local groupId = tonumber(SETTINGS.GroupId) or 0
	if groupId <= 0 then
		return false
	end
	local ok, member = pcall(function()
		return (player :: any):IsInGroupAsync(groupId)
	end)
	if ok and member == true then
		return true
	end
	if listedInGroup(player, groupId) then
		return true
	end
	if justJoined then
		for _, seconds in JOIN_RECHECK_SECONDS do
			task.wait(seconds)
			if player.Parent ~= Players then
				return false
			end
			if listedInGroup(player, groupId) then
				return true
			end
		end
	end
	return false
end

local function verifyGroup(player: Player, justJoined: boolean?): (boolean, string)
	if not U4.IsOn("Community") then
		return false, "Off"
	end
	if discordAllowed[player] == true then
		return false, "UseCode"
	end
	return exclusive(player, function()
		if isClaimed(player) and not pendingPaid[player] then
			return false, "AlreadyClaimed"
		end
		-- 2026-09-25 review: a "not a member yet" answer counts like a wrong code, so tapping
		-- Redeem cannot turn into a group web call every second.
		if tooManyWrong(player) then
			return false, "TooMany"
		end
		if not inGroup(player, justJoined) then
			noteWrong(player)
			return false, "NotMember"
		end
		return claim(player)
	end)
end

-- CodesSystem hands every code it does not know to this, so the community code works in the
-- normal Codes window too. Returns ok, message.
_G.SpeedsterRedeemCommunityCode = function(player: Player, code: any): (boolean, string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return false, messageFor("InvalidCode")
	end
	local ok, reason = redeemCode(player, code)
	send(player, ok, reason)
	return ok, messageFor(reason)
end

local function onRequest(player: Player, action: any, code: any)
	if action == "Get" then
		if U4.IsOn("Community") then
			FunnelAnalytics.Step(player, "Community_Reward", 1)
		end
		send(player, nil, nil)
	elseif action == "Redeem" then
		if discordAllowed[player] ~= true then
			-- The group path's button: the same Redeem, verified by membership. (Step 2 goes
			-- first: the funnel is strict, so Claimed is only counted after a try.)
			if U4.IsOn("Community") then
				FunnelAnalytics.Step(player, "Community_Reward", 2)
			end
			local ok, reason = verifyGroup(player)
			send(player, ok, reason)
			return
		end
		if type(code) == "string" and U4.IsOn("Community") then
			FunnelAnalytics.Step(player, "Community_Reward", 2)
		end
		local ok, reason = redeemCode(player, code)
		send(player, ok, reason)
	elseif action == "VerifyGroup" then
		if U4.IsOn("Community") then
			FunnelAnalytics.Step(player, "Community_Reward", 2)
		end
		-- `code` is "Joined" when the panel's prompt has just made the player a member.
		local ok, reason = verifyGroup(player, code == "Joined")
		send(player, ok, reason)
	end
end
-- 2026-09-26: a request the guard refused (inside its second, or while a group check ran) is
-- answered too, once the guard allows: the tap that "did nothing" on phones.
RemoteGuard.Connect(Request, 1, onRequest, onRequest)

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	task.spawn(lookUpPolicy, player)
	task.spawn(function()
		-- The saved claim, once the profile is loaded, so the panel says CLAIMED on the first open.
		local deadline = os.clock() + 90
		while player.Parent == Players and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.5)
		end
		if player.Parent ~= Players then
			return
		end
		if savedClaim(profileOf(player)) then
			markClaimed(player)
			send(player, nil, nil)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	discordAllowed[player] = nil
	wrongAt[player] = nil
	busy[player] = nil
	pendingPaid[player] = nil
end)
