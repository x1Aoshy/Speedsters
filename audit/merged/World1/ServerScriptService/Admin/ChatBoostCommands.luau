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
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))

local StageTeleportService
pcall(function()
	StageTeleportService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("StageTeleportService"))
end)

local ADMIN_USER_IDS: { [number]: boolean } = {
	[111827288] = true, -- Gekkoh / Owner
	[767108248] = true, -- Admin
	[5113549114] = true, -- Owner
}

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ADMIN_USER_IDS[player.UserId] == true then return true end
	if AdminBannerConfig.IsAdmin(player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	if player:GetAttribute("AdminCommands") == true then return true end
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

local function formatNumber(n: number): string
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

local function parseAmount(raw: any, defaultVal: number?): number?
	if typeof(raw) == "number" then
		if raw ~= raw or raw < 0 or raw == math.huge then return defaultVal end
		return raw
	end
	if typeof(raw) ~= "string" then return defaultVal end
	local clean = string.lower(string.gsub(raw, "[,%s]", ""))
	local numPart, suffix = string.match(clean, "^([%d%.]+e?%d*)([a-z]*)$")
	if not numPart then
		local n = tonumber(clean)
		if n and n == n and n >= 0 and n ~= math.huge then
			return n
		end
		return defaultVal
	end
	local base = tonumber(numPart)
	if not base or base ~= base or base < 0 or base == math.huge then
		return defaultVal
	end
	local mult = 1
	if suffix == "k" then mult = 1e3
	elseif suffix == "m" then mult = 1e6
	elseif suffix == "b" then mult = 1e9
	elseif suffix == "t" then mult = 1e12
	elseif suffix == "qa" or suffix == "q" then mult = 1e15
	elseif suffix == "qi" then mult = 1e18
	elseif suffix == "sx" then mult = 1e21
	elseif suffix == "sp" then mult = 1e24
	elseif suffix == "oc" then mult = 1e27
	elseif suffix == "no" then mult = 1e30
	elseif suffix == "dc" then mult = 1e33
	end
	return base * mult
end

local function resolveTargets(admin: Player, rawTarget: string?): { Player }
	local raw = string.lower(tostring(rawTarget or "me"))
	if raw == "all" or raw == "*" or raw == "everyone" or raw == "todos" then
		return Players:GetPlayers()
	elseif raw == "me" or raw == "self" or raw == "yo" or raw == "" then
		return { admin }
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == raw or string.lower(p.DisplayName) == raw then
				return { p }
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if string.find(string.lower(p.Name), raw, 1, true)
				or string.find(string.lower(p.DisplayName), raw, 1, true) then
				return { p }
			end
		end
	end
	return {}
end

local function commitAdminStat(target: Player, stat: "Speed" | "Wins" | "Rebirths", amount: number): boolean
	local handle = DataService.GetHandle(target.UserId)
	if handle then
		local ok, result = pcall(function()
			return DataService.Commit(handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = "admin_chat_grant:" .. stat .. ":" .. amount,
				commands = { { kind = "GrantExact", stat = stat, amount = amount } },
			})
		end)
		if ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
			if stat == "Speed" and type(_G.SpeedsterApplyWalkSpeed) == "function" then
				pcall(_G.SpeedsterApplyWalkSpeed, target)
			elseif stat == "Rebirths" and type(_G.SpeedsterAddRebirths) == "function" then
				pcall(_G.SpeedsterAddRebirths, target, amount)
			end
			return true
		end
	end

	if stat == "Speed" then
		local cur = tonumber(target:GetAttribute("Speed")) or 0
		target:SetAttribute("Speed", cur + amount)
		if type(_G.SpeedsterAddSpeed) == "function" then
			pcall(_G.SpeedsterAddSpeed, target, amount, 1)
		end
		if type(_G.SpeedsterApplyWalkSpeed) == "function" then
			pcall(_G.SpeedsterApplyWalkSpeed, target)
		end
		return true
	elseif stat == "Wins" then
		local cur = tonumber(target:GetAttribute("Wins")) or 0
		target:SetAttribute("Wins", cur + amount)
		return true
	elseif stat == "Rebirths" then
		local cur = tonumber(target:GetAttribute("Rebirths")) or 0
		target:SetAttribute("Rebirths", cur + amount)
		if type(_G.SpeedsterAddRebirths) == "function" then
			pcall(_G.SpeedsterAddRebirths, target, amount)
		end
		return true
	end
	return false
end

local function calculateSpeedForLevels(startLevel: number, levelDelta: number): number
	local totalSpeed = 0
	local BASE_REQ = 37
	local EARLY_GROWTH = 1.166950047752463
	for lvl = startLevel, startLevel + levelDelta - 1 do
		local req = BASE_REQ * (EARLY_GROWTH ^ math.max(0, lvl - 1))
		totalSpeed += req
	end
	return math.max(100, math.ceil(totalSpeed))
end

local function respawnPlayer(target: Player)
	pcall(function()
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end
		target:LoadCharacter()
	end)
end

local function resolveUserId(raw: string): (number?, string?)
	local num = tonumber(raw)
	if num and num > 0 and num % 1 == 0 then
		local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(num) end)
		return num, if ok and name then name else tostring(num)
	end
	local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(raw) end)
	if ok and id then
		return id, raw
	end
	return nil, nil
end

local function debitAdminStat(target: Player, stat: string, amount: number): boolean
	local handle = DataService.GetHandle(target.UserId)
	if handle then
		pcall(function()
			DataService.Commit(handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = "admin_chat_debit:" .. stat .. ":" .. amount,
				commands = { { kind = "DebitStat", stat = stat, amount = amount } },
			})
		end)
	end
	local cur = tonumber(target:GetAttribute(stat)) or 0
	local floorVal = if stat == "Speed" then 1 else 0
	local newVal = math.max(floorVal, cur - amount)
	target:SetAttribute(stat, newVal)
	local leaderstats = target:FindFirstChild("leaderstats")
	local valObj = leaderstats and leaderstats:FindFirstChild(stat)
	if valObj and valObj:IsA("ValueBase") then
		(valObj :: any).Value = newVal
	end
	if stat == "Speed" and type(_G.SpeedsterApplyWalkSpeed) == "function" then
		pcall(_G.SpeedsterApplyWalkSpeed, target)
	end
	return true
end

local function setAdminStat(target: Player, stat: string, amount: number): boolean
	local handle = DataService.GetHandle(target.UserId)
	if handle then
		pcall(function()
			DataService.Commit(handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = "admin_chat_set:" .. stat .. ":" .. amount,
				commands = { { kind = "SetStat", stat = stat, amount = amount } },
			})
		end)
	end
	local floorVal = if stat == "Speed" then 1 else 0
	local newVal = math.max(floorVal, math.floor(amount))
	target:SetAttribute(stat, newVal)
	local leaderstats = target:FindFirstChild("leaderstats")
	local valObj = leaderstats and leaderstats:FindFirstChild(stat)
	if valObj and valObj:IsA("ValueBase") then
		(valObj :: any).Value = newVal
	end
	if stat == "Speed" and type(_G.SpeedsterApplyWalkSpeed) == "function" then
		pcall(_G.SpeedsterApplyWalkSpeed, target)
	end
	return true
end

local function wipeAdminPlayer(target: Player): boolean
	local handle = DataService.GetHandle(target.UserId)
	if handle then
		pcall(function()
			DataService.Commit(handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = "admin_wipe:" .. target.UserId .. ":" .. os.time(),
				commands = {
					{ kind = "WipeProfile", resetSpeedTo = 1 },
				},
			})
		end)
	end

	target:SetAttribute("Speed", 1)
	target:SetAttribute("Wins", 0)
	target:SetAttribute("Rebirths", 0)
	target:SetAttribute("Level", 1)
	target:SetAttribute("World2Unlocked", false)
	target:SetAttribute("World3Unlocked", false)
	target:SetAttribute("EquippedSkin", "Default")
	target:SetAttribute("EquippedAura", "")
	target:SetAttribute("EquippedTrail", "")
	target:SetAttribute("SpinTickets", 0)
	target:SetAttribute("QuestRewardReady", false)
	target:SetAttribute("VIPGamepassOwned", false)
	target:SetAttribute("VIPSpeedGainMultiplier", 1)
	target:SetAttribute("VIPWinsMultiplier", 1)
	target:SetAttribute("GamepassSpeedGainMultiplier", 1)
	target:SetAttribute("DoubleWinsPadUnlocked", false)
	target:SetAttribute("TwoXVictoryOwned", false)
	target:SetAttribute("InfiniteRevivesOwned", false)
	target:SetAttribute("InfiniteRevivesOwnershipChecked", false)
	target:SetAttribute("DarkZonicOwned", false)
	target:SetAttribute("FlightGamepassOwned", false)
	target:SetAttribute("FlightAbilityOwned", false)
	target:SetAttribute("AdminFlying", false)
	target:SetAttribute("SonicDashPassOwned", false)

	local leaderstats = target:FindFirstChild("leaderstats")
	if leaderstats then
		local s = leaderstats:FindFirstChild("Speed")
		if s and s:IsA("ValueBase") then (s :: any).Value = 1 end
		local w = leaderstats:FindFirstChild("Wins")
		if w and w:IsA("ValueBase") then (w :: any).Value = 0 end
		local r = leaderstats:FindFirstChild("Rebirths")
		if r and r:IsA("ValueBase") then (r :: any).Value = 0 end
	end

	if type(_G.SpeedsterApplyWalkSpeed) == "function" then
		pcall(_G.SpeedsterApplyWalkSpeed, target)
	end
	if type(_G.SpeedsterSyncRebirthAttributes) == "function" then
		pcall(_G.SpeedsterSyncRebirthAttributes, target)
	end
	if type(_G.SpeedsterResetCustomization) == "function" then
		pcall(_G.SpeedsterResetCustomization, target)
	end

	respawnPlayer(target)
	return true
end

local function parseCommand(rawMessage: string): (string?, number?, number?, string?, boolean)
	local msg = string.lower(rawMessage)
	if msg:sub(1, 1) == "/" then
		msg = msg:sub(2)
	else
		return nil, nil, nil, nil, false
	end

	local isCommand = false
	if msg:match("^active") or msg:match("^boost") or msg:match("^2x") or msg:match("^speed2x") or msg:match("^win2x") or msg:match("^grant") then
		isCommand = true
	end
	if not isCommand then
		return nil, nil, nil, nil, false
	end

	local isTargeted = msg:match("^grant") ~= nil

	local boostType: string? = nil
	if msg:find("flight") or msg:find("fly") or msg:find("volar") or msg:find("vuelo") then
		boostType = "Flight"
	elseif msg:find("speed") or msg:find("vel") then
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

	local minutes = (boostType == "Flight" and 20 or 30)
	local foundMin = msg:match("(%d+)%s*m") or msg:match("(%d+)%s*min")
	if foundMin then
		minutes = tonumber(foundMin) or minutes
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

	local targetStr = "all"
	if isTargeted then
		local parts = {}
		for token in rawMessage:gmatch("%S+") do
			table.insert(parts, token)
		end
		-- e.g. /grant speed <target> [minutes] [mult]
		if #parts >= 3 then
			targetStr = parts[3]
		end
		if #parts >= 4 and tonumber(parts[4]) then
			minutes = tonumber(parts[4]) or minutes
		end
		if #parts >= 5 and tonumber(parts[5]) then
			mult = tonumber(parts[5]) or mult
		end
	end

	mult = math.clamp(mult, 2, 100)
	minutes = math.clamp(minutes, 1, 240)

	return boostType, mult, minutes, targetStr, isTargeted
end

local function executeBoost(speaker: Player, boostType: string, mult: number, minutes: number, targetStr: string?, isTargeted: boolean)
	local speakerName = speaker.DisplayName or speaker.Name
	local durationSec = minutes * 60
	targetStr = targetStr or "all"

	if not isTargeted or targetStr == "all" or targetStr == "*" then
		-- Global / Server-wide Boost
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

		if boostType == "Flight" or boostType == "All" then
			for _, p in ipairs(Players:GetPlayers()) do
				pcall(function()
					PotionServer.GrantTemporaryFlight(p, minutes, speakerName)
				end)
			end
		end

		local typeLabel = if boostType == "All" then "Speed, Wins & Flight" else boostType
		local icon = if boostType == "Wins" then "🏆" elseif boostType == "Flight" then "✈️" else "⚡"
		local chatAnnouncement = string.format("<font color='#FFD700'><b>%s [SERVER BOOST] %s has activated %dx %s for %d minutes!</b></font>", icon, speakerName, mult, typeLabel, minutes)
		local screenAnnouncement = string.format("🚀 %s has activated %dx %s for %d minutes!", speakerName, mult, typeLabel, minutes)

		broadcastSystemChatMessage(chatAnnouncement)
		broadcastScreenAnnouncement(speaker, screenAnnouncement)
		print(string.format("[ChatBoostCommands] %s executed /active %s %dx for %dm (All Players)", speaker.Name, typeLabel, mult, minutes))
	else
		-- Targeted Player Grant
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", tostring(targetStr)))
			return
		end

		for _, target in ipairs(targets) do
			if boostType == "Speed" or boostType == "All" then
				PotionServer.GrantSpeedPotion(target, minutes, mult)
			end
			if boostType == "Wins" or boostType == "All" then
				PotionServer.GrantWinsPotion(target, minutes, mult)
			end
			if boostType == "Flight" or boostType == "All" then
				PotionServer.GrantTemporaryFlight(target, minutes, speakerName)
			end
		end

		local typeLabel = if boostType == "All" then "Speed, Wins & Flight" else boostType
		local targetNames = {}
		for _, t in ipairs(targets) do table.insert(targetNames, t.DisplayName or t.Name) end
		local chatAnnouncement = string.format("<font color='#00FFCC'><b>🎁 [GIFT] %s granted %dx %s for %d minutes to %s!</b></font>", speakerName, mult, typeLabel, minutes, table.concat(targetNames, ", "))
		broadcastSystemChatMessage(chatAnnouncement)
		print(string.format("[ChatBoostCommands] %s executed /grant %s to %s (%dx for %dm)", speaker.Name, typeLabel, table.concat(targetNames, ", "), mult, minutes))
	end
end

local function handleAdminCommand(speaker: Player, rawMessage: string): boolean
	local trimmed = string.gsub(rawMessage, "^%s+", "")
	local prefix = string.sub(trimmed, 1, 1)

	local cmdText = trimmed
	if prefix == "/" or prefix == ";" or prefix == ":" or prefix == "!" then
		cmdText = string.sub(trimmed, 2)
	end

	local parts: { string } = {}
	for token in string.gmatch(cmdText, "%S+") do
		table.insert(parts, token)
	end
	if #parts == 0 then return false end

	local root = string.lower(parts[1])

	-- 1. Abrir Panel Admin (/admin, ;admin, /panel, ;panel)
	if root == "admin" or root == "panel" then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local statusRemote = remotes and remotes:FindFirstChild("AdminPanelStatus")
		if statusRemote and statusRemote:IsA("RemoteEvent") then
			statusRemote:FireClient(speaker, { kind = "OpenUI" })
		end
		return true
	end

	-- 2. Ayuda / Comandos
	if root == "help" or root == "cmds" or root == "comandos" or root == "commands" then
		broadcastSystemChatMessage("<font color='#FFD700'><b>👑 [ADMIN COMMANDS]</b></font><br/>"
			.. "<b>/speed</b> [player] [amt] | <b>/removespeed</b> [player] [amt] | <b>/setspeed</b> [player] [amt]<br/>"
			.. "<b>/wins</b> [player] [amt] | <b>/removewins</b> [player] [amt] | <b>/setwins</b> [player] [amt]<br/>"
			.. "<b>/rebirth</b> [player] [amt] | <b>/removerebirth</b> [player] [amt] | <b>/setrebirth</b> [player] [amt]<br/>"
			.. "<b>/tickets</b> [player] [amt] | <b>/removetickets</b> [player] [amt] | <b>/settickets</b> [player] [amt]<br/>"
			.. "<b>/level</b> [player] [amount]<br/>"
			.. "<b>/wipe</b> or <b>/resetall</b> [player] (wipes all stats, skins, worlds to fresh profile!)<br/>"
			.. "<b>/resetstats</b> [player] (resets Speed, Wins, Rebirths and Level to 1/0)<br/>"
			.. "<b>/ban</b> [user|id] [hours] [reason] | <b>/unban</b> [user|id]<br/>"
			.. "<b>/reset</b> or <b>/kill</b> [player] | <b>/bring</b> [player] | <b>/goto</b> [player] | <b>/stage</b> [player] [1-11]<br/>"
			.. "<b>/fly</b> [player] | <b>/unfly</b> [player] | <b>/ragdoll</b> [player] [sec] | <b>/unragdoll</b> [player]<br/>"
			.. "<b>/boost</b> [speed|wins|all] [mult] [min] | <b>/geko</b> [min] | <b>/afk</b> [minutes]"
		)
		return true
	end

	-- AFK test command: /afk [minutos]
	if root == "afk" or root == "setafk" then
		local minutes = 60
		if #parts >= 2 then
			minutes = parseAmount(parts[2], 60) or 60
		end
		if type(_G.SpeedsterTestAfkRewards) == "function" then
			_G.SpeedsterTestAfkRewards(speaker, minutes)
		end

		return true
	end

	-- 3. Speed: /speed [target] [amount] o /speed [amount]
	if root == "speed" or root == "givespeed" or root == "addspeed" then
		local targetStr = "me"
		local amount = 10000
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 10000) or 10000
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then
				amount = num
				targetStr = "me"
			else
				targetStr = parts[2]
				amount = 10000
			end
		end

		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			commitAdminStat(target, "Speed", amount)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00FFAA'>⚡ <b>[Admin]</b> %s granted <b>+%s Speed</b> to <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end

	-- 4. Wins: /wins [target] [amount] o /wins [amount]
	if root == "wins" or root == "givewins" or root == "addwins" or root == "win" then
		local targetStr = "me"
		local amount = 1000
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1000) or 1000
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then
				amount = num
				targetStr = "me"
			else
				targetStr = parts[2]
				amount = 1000
			end
		end

		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			commitAdminStat(target, "Wins", amount)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FFD700'>🏆 <b>[Admin]</b> %s granted <b>+%s Wins</b> to <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end

	-- 5. Rebirths: /rebirth [target] [amount] o /rebirth [amount]
	if root == "rebirth" or root == "rebirths" or root == "giverebirth" or root == "giverebirths" or root == "addrebirth" then
		local targetStr = "me"
		local amount = 1
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1) or 1
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then
				amount = num
				targetStr = "me"
			else
				targetStr = parts[2]
				amount = 1
			end
		end

		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			commitAdminStat(target, "Rebirths", amount)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00E5FF'>🔄 <b>[Admin]</b> %s granted <b>+%d Rebirth(s)</b> to <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end

	-- 6. Levels: /level [target] [amount] o /level [amount]
	if root == "level" or root == "levels" or root == "givelevel" or root == "givelevels" or root == "addlevel" then
		local targetStr = "me"
		local amount = 1
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1) or 1
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then
				amount = num
				targetStr = "me"
			else
				targetStr = parts[2]
				amount = 1
			end
		end

		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			local curLevel = tonumber(target:GetAttribute("Level")) or 1
			local speedGain = calculateSpeedForLevels(curLevel, amount)
			commitAdminStat(target, "Speed", speedGain)
			target:SetAttribute("Level", curLevel + amount)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FFAA00'>⭐ <b>[Admin]</b> %s granted <b>+%d Level(s)</b> to <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end

	-- 6b. Reset Stats: /resetstats [target], /clearstats [target], /statreset [target]
	if root == "resetstats" or root == "clearstats" or root == "statreset" then
		local targetStr = parts[2] or "me"
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			local handle = DataService.GetHandle(target.UserId)
			if handle then
				pcall(function()
					DataService.Commit(handle, {
						operationId = DataService.NewOperationId(),
						fingerprint = "admin_resetstats:" .. target.UserId .. ":" .. os.time(),
						commands = {
							{ kind = "ResetStats", resetSpeedTo = 1 },
						},
					})
				end)
			end

			target:SetAttribute("Speed", 1)
			target:SetAttribute("Wins", 0)
			target:SetAttribute("Rebirths", 0)
			target:SetAttribute("Level", 1)

			if type(_G.SpeedsterApplyWalkSpeed) == "function" then
				pcall(_G.SpeedsterApplyWalkSpeed, target)
			end
			if type(_G.SpeedsterSyncRebirthAttributes) == "function" then
				pcall(_G.SpeedsterSyncRebirthAttributes, target)
			end
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FFAA00'>🔄 <b>[Admin]</b> %s reset all stats of <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, table.concat(names, ", ")))
		print(string.format("[ChatBoostCommands] %s executed /resetstats on %s", speaker.Name, table.concat(names, ", ")))
		return true
	end

	-- 6c. Wipe All Data: /wipe [target], /resetall [target], /resetdata [target], /wipedata [target]
	if root == "wipe" or root == "resetall" or root == "resetdata" or root == "wipedata" or root == "wipeprofile" then
		local targetStr = parts[2] or "me"
		if string.lower(targetStr) == "all" then
			broadcastSystemChatMessage("<font color='#FF5555'>[Admin] Full Wipe cannot be run on 'all' players for safety. Target a specific player or 'me'.</font>")
			return true
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			wipeAdminPlayer(target)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF3333'>💥 <b>[Admin]</b> %s wiped all data of <b>%s</b> (Fresh Profile!)</font>",
			speaker.DisplayName or speaker.Name, table.concat(names, ", ")))
		print(string.format("[ChatBoostCommands] %s executed /wipe on %s", speaker.Name, table.concat(names, ", ")))
		return true
	end

	-- 6d. Remove Speed & Set Speed: /removespeed [target] [amount], /setspeed [target] [amount]
	if root == "removespeed" or root == "takespeed" or root == "debitspeed" then
		local targetStr = "me"
		local amount = 1000
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1000) or 1000
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 1000 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			debitAdminStat(target, "Speed", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF6666'>⚡ <b>[Admin]</b> %s removed <b>-%s Speed</b> from <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end
	if root == "setspeed" then
		local targetStr = "me"
		local amount = 1
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1) or 1
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 1 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			setAdminStat(target, "Speed", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00FFAA'>⚡ <b>[Admin]</b> %s set Speed to <b>%s</b> for <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end

	-- 6e. Remove Wins & Set Wins: /removewins [target] [amount], /setwins [target] [amount]
	if root == "removewins" or root == "takewins" or root == "debitwins" then
		local targetStr = "me"
		local amount = 100
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 100) or 100
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 100 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			debitAdminStat(target, "Wins", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF6666'>🏆 <b>[Admin]</b> %s removed <b>-%s Wins</b> from <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end
	if root == "setwins" then
		local targetStr = "me"
		local amount = 0
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 0) or 0
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 0 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			setAdminStat(target, "Wins", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FFD700'>🏆 <b>[Admin]</b> %s set Wins to <b>%s</b> for <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, formatNumber(amount), table.concat(names, ", ")))
		return true
	end

	-- 6f. Remove Rebirths & Set Rebirths: /removerebirth [target] [amount], /setrebirth [target] [amount]
	if root == "removerebirth" or root == "removerebirths" or root == "takerebirth" or root == "takerebirths" then
		local targetStr = "me"
		local amount = 1
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1) or 1
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 1 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			debitAdminStat(target, "Rebirths", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF6666'>🔄 <b>[Admin]</b> %s removed <b>-%d Rebirth(s)</b> from <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end
	if root == "setrebirth" or root == "setrebirths" then
		local targetStr = "me"
		local amount = 0
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 0) or 0
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 0 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			setAdminStat(target, "Rebirths", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00E5FF'>🔄 <b>[Admin]</b> %s set Rebirths to <b>%d</b> for <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end

	-- 6g. Spin Tickets: /tickets [target] [amount], /removetickets [target] [amount], /settickets [target] [amount]
	if root == "tickets" or root == "givetickets" or root == "addtickets" or root == "ticket" then
		local targetStr = "me"
		local amount = 5
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 5) or 5
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 5 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			local handle = DataService.GetHandle(target.UserId)
			if handle then
				pcall(DataService.Commit, handle, {
					operationId = DataService.NewOperationId(),
					fingerprint = "admin_tickets:" .. amount,
					commands = { { kind = "GrantSpinTickets", amount = amount } },
				})
			end
			local cur = tonumber(target:GetAttribute("SpinTickets")) or 0
			target:SetAttribute("SpinTickets", cur + amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF00FF'>🎟️ <b>[Admin]</b> %s granted <b>+%d Spin Ticket(s)</b> to <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end
	if root == "removetickets" or root == "taketickets" then
		local targetStr = "me"
		local amount = 1
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 1) or 1
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 1 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			debitAdminStat(target, "SpinTickets", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF6666'>🎟️ <b>[Admin]</b> %s removed <b>-%d Spin Ticket(s)</b> from <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end
	if root == "settickets" then
		local targetStr = "me"
		local amount = 0
		if #parts >= 3 then
			targetStr = parts[2]
			amount = parseAmount(parts[3], 0) or 0
		elseif #parts == 2 then
			local num = parseAmount(parts[2], nil)
			if num then amount = num targetStr = "me" else targetStr = parts[2] amount = 0 end
		end
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end
		for _, target in ipairs(targets) do
			setAdminStat(target, "SpinTickets", amount)
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF00FF'>🎟️ <b>[Admin]</b> %s set Spin Tickets to <b>%d</b> for <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, amount, table.concat(names, ", ")))
		return true
	end

	-- 6h. Ban & Unban: /ban [user|id] [hours] [reason], /unban [user|id]
	if root == "ban" then
		local targetStr = parts[2]
		if not targetStr or targetStr == "" then
			broadcastSystemChatMessage("<font color='#FF5555'>[Admin] Usage: /ban &lt;Username|UserId&gt; [hours] [reason]</font>")
			return true
		end
		local hours = tonumber(parts[3]) or 0
		local reason = if #parts >= 4 then table.concat(parts, " ", 4) else "Banned by an admin"
		local userId, username = resolveUserId(targetStr)
		if not userId then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Could not resolve user '%s'.</font>", targetStr))
			return true
		end
		local ok, err = pcall(function()
			Players:BanAsync({
				UserIds = { userId },
				ApplyToUniverse = true,
				Duration = if hours > 0 then math.floor(hours * 3600) else -1,
				DisplayReason = reason,
				PrivateReason = "Admin ban by " .. speaker.Name .. " (" .. speaker.UserId .. ")",
				ExcludeAltAccounts = false,
			})
		end)
		if ok then
			broadcastSystemChatMessage(string.format("<font color='#FF4444'>🔨 <b>[Admin]</b> %s banned <b>%s</b> (ID: %d) for %s</font>",
				speaker.DisplayName or speaker.Name, username or tostring(userId), userId, if hours > 0 then hours .. "h" else "Permanent"))
		else
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Failed to ban %s: %s</font>", targetStr, tostring(err)))
		end
		return true
	end
	if root == "unban" then
		local targetStr = parts[2]
		if not targetStr or targetStr == "" then
			broadcastSystemChatMessage("<font color='#FF5555'>[Admin] Usage: /unban &lt;Username|UserId&gt;</font>")
			return true
		end
		local userId, username = resolveUserId(targetStr)
		if not userId then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Could not resolve user '%s'.</font>", targetStr))
			return true
		end
		local ok, err = pcall(function()
			Players:UnbanAsync({
				UserIds = { userId },
				ApplyToUniverse = true,
			})
		end)
		if ok then
			broadcastSystemChatMessage(string.format("<font color='#00FFAA'>🔓 <b>[Admin]</b> %s unbanned <b>%s</b> (ID: %d)</font>",
				speaker.DisplayName or speaker.Name, username or tostring(userId), userId))
		else
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Failed to unban %s: %s</font>", targetStr, tostring(err)))
		end
		return true
	end

	-- 7. Reset / Kill / Respawn: /reset [target], /kill [target], /respawn [target]
	if root == "reset" or root == "kill" or root == "respawn" then
		local targetStr = parts[2] or "me"
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		for _, target in ipairs(targets) do
			respawnPlayer(target)
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FF4444'>💀 <b>[Admin]</b> %s respawned <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, table.concat(names, ", ")))
		return true
	end

	-- 8. Bring: /bring [target]
	if root == "bring" then
		local targetStr = parts[2] or ""
		local targets = resolveTargets(speaker, targetStr)
		if #targets == 0 then
			broadcastSystemChatMessage(string.format("<font color='#FF5555'>[Admin] Player '%s' not found.</font>", targetStr))
			return true
		end

		local sChar = speaker.Character
		local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
		if not sRoot then
			broadcastSystemChatMessage("<font color='#FF5555'>[Admin] Your character is not available.</font>")
			return true
		end

		for _, target in ipairs(targets) do
			local tChar = target.Character
			local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
			if tRoot and tChar then
				tChar:PivotTo(sRoot.CFrame * CFrame.new(0, 0, -4))
				tRoot.AssemblyLinearVelocity = Vector3.zero
			end
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00E5FF'>📍 <b>[Admin]</b> %s brought <b>%s</b></font>",
			speaker.DisplayName or speaker.Name, table.concat(names, ", ")))
		return true
	end

	-- 9. Goto / TP: /goto [target] o /tp [target] o /tp [target1] [target2]
	if root == "goto" or root == "to" or root == "tp" then
		if #parts >= 3 and root == "tp" then
			local targets1 = resolveTargets(speaker, parts[2])
			local targets2 = resolveTargets(speaker, parts[3])
			local destChar = targets2[1] and targets2[1].Character
			local destRoot = destChar and destChar:FindFirstChild("HumanoidRootPart")
			if destRoot then
				for _, t in ipairs(targets1) do
					local c = t.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if c and r then
						c:PivotTo(destRoot.CFrame * CFrame.new(0, 0, -3))
						r.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end
			return true
		else
			local targetStr = parts[2] or ""
			local targets = resolveTargets(speaker, targetStr)
			local tChar = targets[1] and targets[1].Character
			local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
			local sChar = speaker.Character
			local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
			if tRoot and sChar and sRoot then
				sChar:PivotTo(tRoot.CFrame * CFrame.new(0, 0, -4))
				sRoot.AssemblyLinearVelocity = Vector3.zero
			end
			return true
		end
	end

	-- 10. Stage Teleport: /stage [target] [1-11]
	if root == "stage" or root == "stagetp" then
		local targetStr = "me"
		local stageNum = 1
		if #parts >= 3 then
			targetStr = parts[2]
			stageNum = tonumber(parts[3]) or 1
		elseif #parts == 2 then
			local num = tonumber(parts[2])
			if num then
				stageNum = num
				targetStr = "me"
			else
				targetStr = parts[2]
				stageNum = 1
			end
		end

		local targets = resolveTargets(speaker, targetStr)
		if StageTeleportService and type(StageTeleportService.TeleportToStage) == "function" then
			for _, t in ipairs(targets) do
				StageTeleportService.TeleportToStage(t, stageNum)
			end
		end
		broadcastSystemChatMessage(string.format("<font color='#00FFCC'>🏁 <b>[Admin]</b> Teleported %s to Stage %d</font>",
			targetStr, stageNum))
		return true
	end

	-- 11. Fly / Unfly: /fly [target] / /unfly [target]
	if root == "fly" or root == "unfly" then
		local enabled = (root == "fly")
		local targetStr = parts[2] or "me"
		local targets = resolveTargets(speaker, targetStr)
		for _, target in ipairs(targets) do
			-- The game's own Flight (FlightService). AdminFlying belonged to the retired admin
			-- panel's flight loop: set, it stops Flight and normal movement, so it is only cleared.
			target:SetAttribute("AdminFlying", false)
			if enabled and type(_G.SpeedsterGrantFlight) == "function" then
				pcall(_G.SpeedsterGrantFlight, target, "admin_chat_fly")
			end
		end
		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#00FFAA'>✈️ <b>[Admin]</b> Flight Mode %s for <b>%s</b></font>",
			enabled and "ENABLED" or "DISABLED", table.concat(names, ", ")))
		return true
	end

	-- 12. Geko Giveaway: /geko [minutos] o /giveaway [minutos]
	if root == "geko" or root == "giveaway" then
		local min = tonumber(parts[2]) or 20
		min = math.clamp(min, 1, 240)
		for _, p in ipairs(Players:GetPlayers()) do
			pcall(function()
				PotionServer.GrantTemporaryFlight(p, min, speaker.DisplayName or speaker.Name)
			end)
		end
		broadcastSystemChatMessage(string.format("<font color='#00FFAA'>✈️ <b>[GEKO GIVEAWAY]</b> %s gifted Flight Mode to EVERYONE for %d minutes!</font>",
			speaker.DisplayName or speaker.Name, min))
		return true
	end

	-- 13. Ragdoll / Unragdoll / Trip: /ragdoll [target] [dur], /unragdoll [target], /trip [target]
	if root == "ragdoll" or root == "unragdoll" or root == "trip" then
		local targets = { speaker }
		local duration = 3

		if #parts >= 2 then
			local num = tonumber(parts[2])
			if num then
				duration = num
			else
				targets = resolveTargets(speaker, parts[2])
				if #parts >= 3 and tonumber(parts[3]) then
					duration = tonumber(parts[3]) or duration
				end
			end
		end

		duration = math.clamp(duration, 0.5, 60)

		for _, target in ipairs(targets) do
			local char = target.Character
			if char then
				local bindable = char:FindFirstChild("RagdollEvent")
				if root == "unragdoll" then
					if bindable then
						bindable:Fire("Unragdoll")
					else
						char:SetAttribute("Ragdolled", false)
					end
				elseif root == "trip" then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * 18 + Vector3.new(0, 6, 0)
					end
					char:SetAttribute("RagdollDuration", 2)
					if bindable then
						bindable:Fire("Ragdoll", 2)
					else
						char:SetAttribute("Ragdolled", true)
					end
				else
					char:SetAttribute("RagdollDuration", duration)
					if bindable then
						bindable:Fire("Ragdoll", duration)
					else
						char:SetAttribute("Ragdolled", true)
					end
				end
			end
		end

		local names = {}
		for _, t in ipairs(targets) do table.insert(names, t.DisplayName or t.Name) end
		broadcastSystemChatMessage(string.format("<font color='#FFAA00'><b>[Ragdoll]</b> %s executed /%s on %s (%.1fs)</font>",
			speaker.DisplayName or speaker.Name, root, table.concat(names, ", "), duration))
		return true
	end

	return false
end

local function onMessage(speaker: Player, message: string)
	if not isAllowed(speaker) then
		return
	end

	-- 1. Intentar el nuevo dispatcher completo de comandos de Admin
	if handleAdminCommand(speaker, message) then
		return
	end

	-- 2. Fallback para compatibilidad con boosts de sintaxis libre (/active 2 speed 30, /boost win 20, etc.)
	local text = string.lower(string.gsub(message, "^%s+", ""))
	local boostType, mult, minutes, targetStr, isTargeted = nil, 2, 30, "all", false
	if text:sub(1, 1) == "/" or text:sub(1, 1) == ";" or text:sub(1, 1) == ":" or text:sub(1, 1) == "!" then
		local sub = text:sub(2)
		if sub:match("^active") or sub:match("^boost") or sub:match("^2x") or sub:match("^grant") then
			if sub:find("flight") or sub:find("fly") or sub:find("volar") then
				boostType = "Flight"
			elseif sub:find("win") or sub:find("vic") then
				boostType = "Wins"
			else
				boostType = "Speed"
			end

			local foundMult = sub:match("%*%s*(%d+)") or sub:match("(%d+)%s*x") or sub:match("x%s*(%d+)")
			if foundMult then mult = tonumber(foundMult) or 2 end

			local foundMin = sub:match("(%d+)%s*m") or sub:match("(%d+)%s*min")
			if foundMin then minutes = tonumber(foundMin) or 30 end

			executeBoost(speaker, boostType, mult, minutes, targetStr, isTargeted)
		end
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
