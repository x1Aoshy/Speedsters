--!strict
-- SpinWheelService.server.luau
-- Server side of the Spin Wheel. Spends a spin and pays its reward in ONE profile
-- transaction, so a spin can never be paid without being spent, or spent without
-- being paid. The panel and the lobby wheel are client-side (UI/SpinWheelController).
--
-- A spin comes from, in order: the free spin of the current window, then a Spin
-- Ticket. Tickets come from Quests, the AFK Zone, the Robux packs (Config.SpinWheel
-- .Products, granted by SpeedProductPurchases) and a capped Wins purchase.
--
-- A preview feature (Shared.FeatureGate): only preview players are served.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local settings = Config.SpinWheel
if type(settings) ~= "table" or settings.Enabled ~= true then
	return
end

local FeatureGate = require(Shared:WaitForChild("FeatureGate"))
local SpinWheelCatalog = require(Shared:WaitForChild("SpinWheelCatalog"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
local RateLimiter = require(ServerScriptService:WaitForChild("Services"):WaitForChild("ServerRateLimiter"))
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
local function remote(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local Request = remote("SpinWheelRequest")
local Update = remote("SpinWheelUpdate")

local WINDOW = math.max(60, math.floor(tonumber(settings.FreeSpinWindowSeconds) or 10800))
local COMMIT_ATTEMPTS = 6
local winsSettings = type(settings.WinsPurchase) == "table" and settings.WinsPurchase or {}
local WINS_ENABLED = winsSettings.Enabled == true
local WINS_LIMIT = math.max(1, math.floor(tonumber(winsSettings.MaxPerWindow) or 2))
local WINS_WINDOW = math.max(60, math.floor(tonumber(winsSettings.WindowSeconds) or 3600))
local random = Random.new()

local busy: { [Player]: boolean } = {}
local restricted: { [Player]: boolean } = {}

local function currentPeriod(now: number): number
	return math.floor(now / WINDOW)
end

local function inspect(player: Player)
	if player:GetAttribute("DataLoaded") ~= true then
		return nil, nil
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return nil, nil
	end
	local result = DataService.Inspect(handle)
	if not result.ok or not result.value.profile then
		return nil, nil
	end
	return result.value.profile, handle
end

-- What a lap of this place's world pays, for the Wins prizes.
local WORLD_KEY = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" else "World1"
local LAP = tonumber(settings.LapWins and settings.LapWins[WORLD_KEY]) or 0
local SHARES = { Small = tonumber(settings.SmallLapShare) or 0.15, Large = tonumber(settings.LargeLapShare) or 0.6 }

-- Level is not saved in the profile; LevelProgress derives it and publishes it on the player.
local function context(player: Player, profile: any): SpinWheelCatalog.Context
	return {
		Level = math.max(1, tonumber(player:GetAttribute("Level")) or 1),
		Speed = math.max(0, tonumber(profile.Speed) or 0),
		Lap = LAP,
		Shares = SHARES,
	}
end

-- Paid spins are paid random items. Until the policy lookup answers, treat the player
-- as restricted: hiding a purchase for a moment is safe, showing one is not.
local function lookUpPolicy(player: Player)
	restricted[player] = true
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if player.Parent ~= Players then
		return
	end
	if not ok and RunService:IsStudio() then
		-- Studio test accounts often have no policy to read; show the packs there.
		restricted[player] = false
		return
	end
	restricted[player] = not (ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false)
end

local function paidSpinsAllowed(player: Player): boolean
	return restricted[player] == false
end

local function productByKey(key: any)
	for _, product in settings.Products or {} do
		if product.Key == key then
			return product
		end
	end
	return nil
end

local function winsSpinCost(player: Player): number
	return SpinWheelCatalog.WinsSpinCost(
		math.max(1, tonumber(player:GetAttribute("Level")) or 1),
		math.max(1, tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1),
		winsSettings,
		tonumber(Config.ProgressionPriceMultiplierExponent)
	)
end

-- How many Wins spins are left in the player's window, and when the window resets.
local function winsWindow(profile: any, now: number): (number, number)
	local start = tonumber(profile.SpinWinsWindowStart) or 0
	local count = tonumber(profile.SpinWinsWindowCount) or 0
	if now - start >= WINS_WINDOW then
		return WINS_LIMIT, 0
	end
	return math.max(0, WINS_LIMIT - count), start + WINS_WINDOW
end

local function statePayload(player: Player, profile: any, extra: { [string]: any }?)
	local now = os.time()
	local period = currentPeriod(now)
	local ctx = context(player, profile)
	local segments = {}
	for index, segment in SpinWheelCatalog.Segments do
		table.insert(segments, {
			Id = segment.Id,
			Icon = segment.Icon,
			Label = SpinWheelCatalog.ShortLabel(index, ctx),
			Odds = SpinWheelCatalog.OddsText(index),
			Rare = segment.Rare == true,
		})
	end
	local allowed = paidSpinsAllowed(player)
	local products = {}
	if allowed then
		for _, product in settings.Products or {} do
			local id = tonumber(product.ProductId)
			table.insert(products, {
				Key = product.Key,
				Button = product.Button,
				Spins = product.Spins,
				PriceRobux = product.PriceRobux,
				ProductId = if id and id > 0 then id else nil,
			})
		end
	end
	local remaining, resetsAt = winsWindow(profile, now)
	local payload = {
		Tickets = math.max(0, math.floor(tonumber(profile.SpinTickets) or 0)),
		FreeAvailable = (tonumber(profile.SpinWheelFreePeriod) or 0) < period,
		NextFreeAt = (period + 1) * WINDOW,
		ServerTime = now,
		Segments = segments,
		PaidSpinsAllowed = allowed,
		Products = products,
		WinsPurchase = if WINS_ENABLED and allowed
			then {
				Cost = winsSpinCost(player),
				Remaining = remaining,
				Limit = WINS_LIMIT,
				ResetsAt = resetsAt,
				Wins = math.max(0, tonumber(profile.Wins) or 0),
			}
			else nil,
	}
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	return payload
end

local function send(player: Player, extra: { [string]: any }?)
	if player.Parent ~= Players or not FeatureGate.IsPreviewPlayer(player) then
		return
	end
	local profile = inspect(player)
	if not profile then
		Update:FireClient(player, { Loading = true, Message = extra and extra.Message or nil })
		return
	end
	Update:FireClient(player, statePayload(player, profile, extra))
end

local function pickRareCosmetic(profile: any): (string?, string?)
	local owned = {
		Aura = profile.OwnedAuras or {},
		Trail = profile.OwnedTrails or {},
	}
	local unowned = {}
	for _, cosmetic in SpinWheelCatalog.RareCosmetics do
		if not table.find(owned[cosmetic.Type] or {}, cosmetic.Id) then
			table.insert(unowned, cosmetic)
		end
	end
	if #unowned == 0 then
		return nil, nil
	end
	local chosen = unowned[random:NextInteger(1, #unowned)]
	return chosen.Type, chosen.Id
end

-- The reward commands for a segment, plus how the result reads to the player.
local function rewardFor(player: Player, index: number, profile: any): ({ any }, string)
	local segment = SpinWheelCatalog.Segments[index]
	local ctx = context(player, profile)
	local function wins(tier: string, times: number)
		local amount = SpinWheelCatalog.WinsAmount(tier, ctx.Level, ctx.Lap, ctx.Shares) * times
		return { { kind = "GrantExact", stat = "Wins", amount = amount } }, "+" .. SpinWheelCatalog.FormatNumber(amount) .. " Wins!"
	end

	if segment.Kind == "Wins" then
		return wins(segment.Tier or "Small", 1)
	elseif segment.Kind == "Speed" then
		local amount = SpinWheelCatalog.SpeedAmount(segment.Tier, ctx.Speed)
		return { { kind = "GrantExact", stat = "Speed", amount = amount } }, "+" .. SpinWheelCatalog.FormatNumber(amount) .. " Speed!"
	elseif segment.Kind == "PotionSpeed" or segment.Kind == "PotionWins" then
		local minutes = segment.Minutes or 10
		local buff = if segment.Kind == "PotionSpeed" then "SpeedPotion" else "WinsPotion"
		return { { kind = "GrantBuff", grant = { kind = buff, addedSeconds = minutes * 60, multiplier = 2, bottleType = "Small" } } },
			(if segment.Kind == "PotionSpeed" then "2x Speed" else "2x Wins") .. " for " .. tostring(minutes) .. " min!"
	elseif segment.Kind == "Exclusive" then
		-- Aura 67 and the Tung Tung Sahur skin exist nowhere else. Granted in the same
		-- commit that spends the spin; equipped from the Backpack or the Index.
		local id = segment.CosmeticId
		if segment.Cosmetic == "Aura" and id and not table.find(profile.OwnedAuras or {}, id) then
			return { { kind = "GrantAura", auraId = id } }, string.upper(segment.Title or id) .. " UNLOCKED! Equip it in your Backpack"
		elseif segment.Cosmetic == "Skin" and id and not table.find(profile.OwnedSkins or {}, id) then
			return { { kind = "GrantSkin", skinId = id } }, string.upper(segment.Title or id) .. " UNLOCKED! Equip it in the Index"
		end
		-- Already owned: a shop cosmetic the player lacks, then Wins.
		local cosmeticType, cosmeticId = pickRareCosmetic(profile)
		if cosmeticType == "Aura" and cosmeticId then
			return { { kind = "GrantAura", auraId = cosmeticId } }, "Rare Aura unlocked!"
		elseif cosmeticType == "Trail" and cosmeticId then
			return { { kind = "GrantTrail", trailId = cosmeticId } }, "Rare Trail unlocked!"
		end
		return wins("Large", SpinWheelCatalog.RareFallbackWinsMultiplier)
	end
	return wins("Small", 1)
end

local function commit(handle: any, request: any): (boolean, string?)
	for _ = 1, COMMIT_ATTEMPTS do
		local ok, result = pcall(DataService.Commit, handle, request)
		if not ok then
			warn("[SpinWheelService] Commit failed: " .. tostring(result))
			return false, nil
		end
		if result.kind == "Committed" or result.kind == "AlreadyCommitted" then
			return true, nil
		end
		if result.kind ~= "Pending" then
			return false, if type(result.error) == "table" then result.error.message else nil
		end
		-- Same operation id: a retry either lands it or finds it already landed.
		task.wait(math.max(0.25, tonumber(result.retryAfterSeconds) or 1))
	end
	return false, nil
end

local function exclusive(player: Player, work: () -> ())
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(work)
	busy[player] = nil
	if not ok then
		warn("[SpinWheelService] " .. player.Name .. ": " .. tostring(err))
		send(player, { Message = "That did not go through. Try again." })
	end
end

local function broadcastGlobalSpinPrize(player: Player, segment: any, prizeTitle: string)
	local isMythic = segment.Rarity == "Mythic" or segment.Id == "TungTung"
	local theme = if isMythic then "Rainbow" else "Gold"
	local displayName = player.DisplayName or player.Name
	local payload = {
		Message = string.format("%s won %s on the Spin Wheel! 🎉", displayName, prizeTitle),
		EventId = HttpService:GenerateGUID(false),
		OriginJobId = game.JobId,
		SenderName = "SPIN WHEEL",
		SenderId = player.UserId,
		Duration = 7,
		Timestamp = os.time(),
		Theme = theme,
	}

	local displayRemote = Remotes:FindFirstChild("DisplayGlobalAnnouncement")
	if displayRemote and displayRemote:IsA("RemoteEvent") then
		displayRemote:FireAllClients(payload)
	end

	if not RunService:IsStudio() then
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync("SpeedsterGlobalAnnouncements_v1", payload)
			end)
		end)
	end

	pcall(function()
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
		if generalChannel and generalChannel:IsA("TextChannel") then
			generalChannel:DisplaySystemMessage(string.format("<font color='#FFD700'><b>[SPIN WHEEL]</b> %s won <b>%s</b> on the Spin Wheel! 🎉</font>", displayName, prizeTitle))
		end
	end)
end

local function spin(player: Player)
	local profile, handle = inspect(player)
	if not profile or not handle then
		send(player, { Message = "Your data is still loading." })
		return
	end

	local period = currentPeriod(os.time())
	local spend
	if (tonumber(profile.SpinWheelFreePeriod) or 0) < period then
		spend = { kind = "ClaimFreeSpin", period = period }
	elseif (tonumber(profile.SpinTickets) or 0) >= 1 then
		spend = { kind = "SpendSpinTicket" }
	else
		send(player, { Message = "No spins left!", NoSpins = true })
		return
	end

	local index = SpinWheelCatalog.Pick(random:NextNumber())
	local commands, title = rewardFor(player, index, profile)
	table.insert(commands, 1, spend)

	local operationId = "spinwheel:" .. tostring(player.UserId) .. ":" .. DataService.NewOperationId()
	if not commit(handle, { operationId = operationId, fingerprint = "spinwheel", commands = commands }) then
		send(player, { Message = "That spin did not go through. Nothing was used." })
		return
	end
	if spend.kind == "ClaimFreeSpin" then
		FunnelAnalytics.Step(player, "Engagement_SpinWheel", 2)
	end

	local segment = SpinWheelCatalog.Segments[index]
	local isEpicOrRare = segment and (segment.Rare == true or segment.Kind == "Exclusive" or segment.Rarity == "Mythic" or segment.Rarity == "Legendary")
	if isEpicOrRare then
		local prizeName = segment.Title or segment.Label or (segment.Kind == "Wins" and "Huge Wins") or "an Epic Prize"
		task.spawn(broadcastGlobalSpinPrize, player, segment, prizeName)
	end

	local fresh = inspect(player)
	if fresh then
		local payload = statePayload(player, fresh)
		payload.Result = { Index = index, Id = SpinWheelCatalog.Segments[index].Id, Title = title }
		Update:FireClient(player, payload)
	end
end

local function formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function buyWithWins(player: Player)
	if not WINS_ENABLED or not paidSpinsAllowed(player) then
		return
	end
	local profile, handle = inspect(player)
	if not profile or not handle then
		send(player, { Message = "Your data is still loading." })
		return
	end
	local now = os.time()
	local remaining, resetsAt = winsWindow(profile, now)
	if remaining <= 0 then
		send(player, { Message = "Wins spins refill in " .. formatClock(resetsAt - now) })
		return
	end
	local cost = winsSpinCost(player)
	if (tonumber(profile.Wins) or 0) < cost then
		send(player, { Message = "You need " .. SpinWheelCatalog.FormatNumber(cost) .. " Wins" })
		return
	end
	local operationId = "spinwins:" .. tostring(player.UserId) .. ":" .. DataService.NewOperationId()
	local ok, reason = commit(handle, {
		operationId = operationId,
		fingerprint = "spinwins:" .. tostring(cost),
		commands = {
			{ kind = "DebitWins", amount = cost },
			{ kind = "RecordWinsSpin", window = WINS_WINDOW, limit = WINS_LIMIT },
			{ kind = "GrantSpinTickets", amount = 1 },
		},
	})
	if not ok then
		send(player, { Message = if reason == "Wins spin limit reached" then "No Wins spins left this hour" else "Purchase did not go through. No Wins were spent." })
		return
	end
	FunnelAnalytics.Step(player, "Engagement_SpinWheel", 5)
	send(player, { Message = "+1 Spin!", Bought = "Wins" })
end

Request.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" or not FeatureGate.IsPreviewPlayer(player) then
		return
	end
	if payload.action == "State" then
		if not RateLimiter.Allow(player, "SpinWheelState", 0.05) then
			return
		end
		-- The panel sends `opened` when it opens: a new run of the Spin Wheel funnel.
		if payload.opened == true then
			FunnelAnalytics.Step(player, "Engagement_SpinWheel", 1, FunnelAnalytics.NewSession(player, "Engagement_SpinWheel"))
		end
		send(player)
		return
	end

	if not RateLimiter.Allow(player, "SpinWheelRequest", 0.35) then
		return
	end
	if payload.action == "Spin" then
		exclusive(player, function()
			spin(player)
		end)
	elseif payload.action == "BuyWithWins" then
		exclusive(player, function()
			buyWithWins(player)
		end)
	elseif payload.action == "Buy" and type(payload.key) == "string" then
		-- The server opens the prompt, and only for a pack this player may be offered:
		-- paid spins are hidden wherever paid random items are restricted.
		local product = productByKey(payload.key)
		local productId = product and tonumber(product.ProductId)
		if not product or not paidSpinsAllowed(player) then
			return
		end
		if not productId or productId <= 0 then
			send(player, { Message = "Spin packs are coming soon!" })
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[SpinWheelService] Could not open the spin pack prompt: " .. tostring(err))
		else
			FunnelAnalytics.Step(player, "Engagement_SpinWheel", 3)
		end
	end
end)

-- Refresh the panel when tickets or Wins change elsewhere (quests, AFK zone, purchases).
local function watch(player: Player)
	if not FeatureGate.IsPreviewPlayer(player) then
		return
	end
	task.spawn(lookUpPolicy, player)
	local queued = false
	local function refresh()
		if queued or busy[player] then
			return
		end
		queued = true
		task.delay(0.5, function()
			queued = false
			send(player)
		end)
	end
	player:GetAttributeChangedSignal("SpinTickets"):Connect(refresh)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			send(player)
		end
	end)
	if player:GetAttribute("DataLoaded") == true then
		task.defer(send, player)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	task.spawn(watch, player)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	restricted[player] = nil
end)

print("[SpinWheelService] ready | free spin every " .. tostring(WINDOW) .. "s | segments=" .. tostring(#SpinWheelCatalog.Segments) .. " | wins spins " .. tostring(WINS_LIMIT) .. "/" .. tostring(WINS_WINDOW) .. "s")
