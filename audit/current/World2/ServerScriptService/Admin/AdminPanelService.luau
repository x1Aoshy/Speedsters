--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))

local WORLD_1_PLACE_ID = 85065221510105
local MESSAGING_TOPIC = "SpeedsterGlobalAnnouncements_v1"

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

local AdminPanelAction = ensureRemote("AdminPanelAction")
local AdminPanelStatus = ensureRemote("AdminPanelStatus")
local DisplayRemote = ensureRemote("DisplayGlobalAnnouncement")

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ALLOWED_USER_IDS[player.UserId] == true then return true end
	if AdminBannerConfig.IsAdmin(player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local function sendToast(player: Player, success: boolean, message: string)
	if player and player.Parent == Players then
		AdminPanelStatus:FireClient(player, {
			kind = "Toast",
			success = success,
			message = message,
		})
	end
end

local function resolveTargets(admin: Player, rawTarget: any): { Player }
	if rawTarget == "All" or rawTarget == "all" then
		return Players:GetPlayers()
	elseif rawTarget == "Self" or rawTarget == "self" or rawTarget == nil then
		return { admin }
	else
		local numId = tonumber(rawTarget)
		if numId then
			local p = Players:GetPlayerByUserId(numId)
			if p then return { p } end
		end
		if typeof(rawTarget) == "string" then
			local lower = string.lower(rawTarget)
			for _, p in ipairs(Players:GetPlayers()) do
				if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
					return { p }
				end
			end
		end
	end
	return { admin }
end

local function filterText(player: Player, text: string): string
	if RunService:IsStudio() then return text end
	local filtered = text
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId)
	end)
	if ok and result then
		local okB, broadcastText = pcall(function()
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if okB and broadcastText then filtered = broadcastText end
	end
	return filtered
end

-- State for Auto Rebirths per admin
type AutoRebirthConfig = {
	enabled: boolean,
	mode: "Threshold" | "Forced",
	lastRun: number,
}
local autoRebirthAdmins: { [number]: AutoRebirthConfig } = {}

-- Auto Rebirth loop
task.spawn(function()
	while true do
		task.wait(1.0)
		for userId, cfg in pairs(autoRebirthAdmins) do
			if cfg.enabled then
				local player = Players:GetPlayerByUserId(userId)
				if player and player.Parent == Players then
					local now = os.clock()
					if cfg.mode == "Forced" then
						if now - cfg.lastRun >= 3.0 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, true)
							end
						end
					else
						-- Threshold mode: only rebirth if player meets level requirement
						local level = tonumber(player:GetAttribute("Level")) or 1
						local reqLevel = tonumber(player:GetAttribute("NextRebirthLevelRequired")) or 5
						if level >= reqLevel and now - cfg.lastRun >= 1.5 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, false)
							end
						end
					end
				else
					autoRebirthAdmins[userId] = nil
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	autoRebirthAdmins[player.UserId] = nil
end)

-- Apply pass state (enable or disable) for a target player
local function applyPassToggle(target: Player, passId: string, enabled: boolean)
	local handle = DataService.GetHandle(target.UserId)
	local commands = {}

	if passId == "VIP" or passId == "All" then
		target:SetAttribute("VIPGamepassOwned", enabled)
		target:SetAttribute("VIPSpeedGainMultiplier", enabled and (tonumber(Config.VipSpeedGainMultiplier) or 2) or 1)
		target:SetAttribute("VIPWinsMultiplier", enabled and (tonumber(Config.VipWinsMultiplier) or 2) or 1)
		table.insert(commands, {
			kind = if enabled then "GrantUpgrade" else "RemoveUpgrade",
			upgradeId = "VIP",
		})
	end

	if passId == "Flight" or passId == "All" then
		target:SetAttribute("FlightAbilityOwned", enabled)
		table.insert(commands, {
			kind = if enabled then "GrantUpgrade" else "RemoveUpgrade",
			upgradeId = "Flight",
		})
	end

	if passId == "TwoXSpeed" or passId == "All" then
		target:SetAttribute("PermanentBaseSpeedMultiplier", enabled and 2 or 1)
		target:SetAttribute("GamepassSpeedGainMultiplier", enabled and 2 or 1)
		table.insert(commands, {
			kind = if enabled then "GrantUpgrade" else "RemoveUpgrade",
			upgradeId = "TwoXSpeed",
		})
		table.insert(commands, {
			kind = "SetPersistent",
			key = "PermanentBaseSpeedMultiplier",
			value = enabled and 2 or 1,
		})
	end

	if passId == "TwoXVictory" or passId == "All" then
		target:SetAttribute("PermanentWinsMultiplier", enabled and 2 or 1)
		target:SetAttribute("DoubleWinsPadUnlocked", enabled)
		target:SetAttribute("TwoXVictoryOwned", enabled)
		if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
			_G.SpeedsterSetPermanentWinsMultiplier(target, enabled and 2 or 1)
		end
		table.insert(commands, {
			kind = if enabled then "GrantUpgrade" else "RemoveUpgrade",
			upgradeId = "TwoXVictory",
		})
		table.insert(commands, {
			kind = "SetPersistent",
			key = "PermanentWinsMultiplier",
			value = enabled and 2 or 1,
		})
	end

	if passId == "InfiniteRevives" or passId == "All" then
		target:SetAttribute("InfiniteRevivesOwned", enabled)
		target:SetAttribute("InfiniteRevivesOwnershipChecked", true)
		table.insert(commands, {
			kind = if enabled then "GrantUpgrade" else "RemoveUpgrade",
			upgradeId = "InfiniteRevives",
		})
	end

	if passId == "DarkZonic" or passId == "All" then
		target:SetAttribute("DarkZonicOwned", enabled)
		table.insert(commands, {
			kind = if enabled then "GrantSkin" else "RemoveSkin",
			skinId = "DarkZonic",
		})
	end

	if handle and #commands > 0 then
		DataService.Commit(handle, {
			operationId = "admin_pass_" .. target.UserId .. "_" .. passId .. "_" .. tostring(enabled) .. "_" .. tostring(os.clock()),
			commands = commands,
		})
	end
end

-- Server request listener
AdminPanelAction.OnServerEvent:Connect(function(player: Player, payload: any)
	if not isAllowed(player) then return end
	if typeof(payload) ~= "table" then return end

	local action = payload.action

	if action == "CheckPermission" then
		local boostExp = tonumber(Workspace:GetAttribute("ServerBoostExpiresUnix")) or 0
		local remainingBoost = math.max(0, boostExp - os.time())
		local cfg = autoRebirthAdmins[player.UserId]
		AdminPanelStatus:FireClient(player, {
			kind = "Permission",
			allowed = true,
			displayName = player.DisplayName,
			serverBoostRemaining = remainingBoost,
			autoRebirthEnabled = cfg and cfg.enabled == true or false,
			autoRebirthMode = cfg and cfg.mode or "Threshold",
			world2Unlocked = player:GetAttribute("World2Unlocked") == true,
		})

	elseif action == "ServerBoost" then
		local minutes = math.clamp(math.floor(tonumber(payload.minutes) or 15), 1, 240)
		local mult = 2
		local grant = PotionServer.GrantServerBoost(minutes, mult, player.DisplayName)
		if grant and grant.Notify then
			grant.Notify()
		end

		-- Also give all players 2x Wins Potion for the same duration
		for _, p in ipairs(Players:GetPlayers()) do
			pcall(function()
				local winGrant = PotionServer.GrantWinsPotion(p, minutes, mult)
				if winGrant and winGrant.Notify then
					winGrant.Notify()
				end
			end)
		end

		sendToast(player, true, "⚡ ¡Boost 2x Speed & 2x Wins activado para el servidor por " .. minutes .. "m!")

	elseif action == "GiveRebirths" then
		local amount = math.clamp(math.floor(tonumber(payload.amount) or 1), 1, 10000)
		local targets = resolveTargets(player, payload.target)

		for _, target in ipairs(targets) do
			if type(_G.SpeedsterAddRebirths) == "function" then
				_G.SpeedsterAddRebirths(target, amount)
			else
				local handle = DataService.GetHandle(target.UserId)
				if handle then
					DataService.Commit(handle, {
						operationId = "admin_rebirth_" .. target.UserId .. "_" .. tostring(os.clock()),
						commands = { { kind = "GrantExact", stat = "Rebirths", amount = amount } },
					})
				end
			end
			if target ~= player then
				sendToast(target, true, "🎁 ¡El Administrador te otorgó +" .. amount .. " Rebirths!")
			end
		end

		local desc = if payload.target == "All" or payload.target == "all" then "todos los jugadores" else (targets[1] and targets[1].DisplayName or "jugador")
		sendToast(player, true, "✅ +" .. amount .. " Rebirths otorgados a " .. desc)

	elseif action == "GiveStats" then
		local stat = if payload.stat == "Wins" then "Wins" else "Speed"
		local amount = math.clamp(math.floor(tonumber(payload.amount) or 1000), 1, 1e14)
		local targets = resolveTargets(player, payload.target)

		for _, target in ipairs(targets) do
			if type(_G.SpeedsterGrantExactStat) == "function" then
				_G.SpeedsterGrantExactStat(target, stat, amount)
			else
				local handle = DataService.GetHandle(target.UserId)
				if handle then
					DataService.Commit(handle, {
						operationId = "admin_stat_" .. target.UserId .. "_" .. stat .. "_" .. tostring(os.clock()),
						commands = { { kind = "GrantExact", stat = stat, amount = amount } },
					})
				end
			end
			if stat == "Speed" and type(_G.SpeedsterApplyWalkSpeed) == "function" then
				_G.SpeedsterApplyWalkSpeed(target)
			end
			if target ~= player then
				sendToast(target, true, "🎁 ¡El Administrador te otorgó +" .. amount .. " " .. stat .. "!")
			end
		end

		local desc = if payload.target == "All" or payload.target == "all" then "todos los jugadores" else (targets[1] and targets[1].DisplayName or "jugador")
		sendToast(player, true, "✅ +" .. amount .. " " .. stat .. " otorgados a " .. desc)

	elseif action == "TogglePass" then
		local passId = tostring(payload.pass or "VIP")
		local enabled = payload.enabled == true
		local targets = resolveTargets(player, payload.target)

		for _, target in ipairs(targets) do
			applyPassToggle(target, passId, enabled)
			if target ~= player then
				sendToast(target, true, "🎟️ Pase " .. passId .. (enabled and " ACTIVADO" or " DESACTIVADO") .. " por el Administrador.")
			end
		end

		local desc = if payload.target == "All" or payload.target == "all" then "todos los jugadores" else (targets[1] and targets[1].DisplayName or "jugador")
		sendToast(player, true, "✅ Pase " .. passId .. (enabled and " ACTIVADO" or " DESACTIVADO") .. " para " .. desc)

	elseif action == "AutoRebirth" then
		local enabled = payload.enabled == true
		local mode = if payload.mode == "Forced" then "Forced" else "Threshold"

		autoRebirthAdmins[player.UserId] = {
			enabled = enabled,
			mode = mode,
			lastRun = 0,
		}

		local modeText = if mode == "Forced" then "Rápido (cada 3s, reinicia stats)" else "Al cumplir nivel requerido"
		sendToast(player, true, "🔄 Auto Rebirth: " .. (enabled and "ACTIVADO [" .. modeText .. "]" or "DESACTIVADO"))

	elseif action == "ManualRebirthReset" then
		if type(_G.SpeedsterPerformRebirth) == "function" then
			_G.SpeedsterPerformRebirth(player, true)
			sendToast(player, true, "✨ ¡Rebirth forzado completado! Stats reiniciados a 1 y +1 Rebirth.")
		else
			sendToast(player, false, "RebirthSystem no disponible.")
		end

	elseif action == "UnlockWorld2" then
		local enabled = payload.enabled ~= false
		local targets = resolveTargets(player, payload.target)

		for _, target in ipairs(targets) do
			target:SetAttribute("World2Unlocked", enabled)
			local handle = DataService.GetHandle(target.UserId)
			if handle then
				DataService.Commit(handle, {
					operationId = "admin_w2_unlock_" .. target.UserId .. "_" .. tostring(os.clock()),
					fingerprint = "admin_w2_" .. tostring(enabled),
					commands = { { kind = "SetPersistent", key = "World2Unlocked", value = enabled, allowFalse = true } },
				})
			end
		end

		local desc = if payload.target == "All" or payload.target == "all" then "todos los jugadores" else (targets[1] and targets[1].DisplayName or "jugador")
		sendToast(player, true, "🌍 World 2 " .. (enabled and "DESBLOQUEADO" or "BLOQUEADO") .. " para " .. desc)

	elseif action == "TeleportWorld1" then
		sendToast(player, true, "🚀 Teletransportando a World 1...")
		pcall(function()
			TeleportService:Teleport(WORLD_1_PLACE_ID, player)
		end)

	elseif action == "BroadcastAnnouncement" then
		local rawMsg = tostring(payload.message or "")
		local trimmed = string.match(rawMsg, "^%s*(.-)%s*$") or ""
		if #trimmed == 0 then
			sendToast(player, false, "El mensaje no puede estar vacío.")
			return
		end
		if #trimmed > 250 then trimmed = string.sub(trimmed, 1, 250) end

		local filtered = filterText(player, trimmed)
		local annPayload = {
			Message = filtered,
			SenderName = player.DisplayName or player.Name,
			SenderId = player.UserId,
			Duration = 8,
			Timestamp = os.time(),
		}

		DisplayRemote:FireAllClients(annPayload)

		if not RunService:IsStudio() then
			task.spawn(function()
				pcall(function()
					MessagingService:PublishAsync(MESSAGING_TOPIC, annPayload)
				end)
			end)
		end

		sendToast(player, true, "📢 Anuncio global transmitido a todos.")
	end
end)

print("[AdminPanelService] Loaded successfully in World 2. Authorized admins have full control.")
