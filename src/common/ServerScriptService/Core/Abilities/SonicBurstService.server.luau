-- SonicBurstService.server.luau
-- The Sonic Burst ability (its card in the Abilities panel, AbilitiesPanel.client):
--
--   * Buy: Config.AbilitySonicBurstWinsCost Wins, damped by the permanent Wins multiplier
--     exactly as Flight is (Shared.WinsMath.GetProgressionPrice against
--     _G.SpeedsterGetPermanentWinsMultiplier): one profile transaction charges it, grants
--     the upgrade and equips it. The price shown and the price charged come from winsCost.
--   * Equip / Unequip: a marker upgrade (__AbilityEquipped_SonicBurst) in the profile.
--   * Charge: the owner holds the sprint (Shift, the gamepad's sprint trigger, or the touch
--     button) and the stamina bar drains; the server checks it is owned and equipped, off
--     cooldown, and the character alive, standing and not flying, and every client draws
--     the charging bubble (Movement/SonicBurstClient). Cancel takes it away.
--   * Fire: let go, with how full the charge got (0..1). The bubble bursts on every client
--     and the owner's client throws its own character forward (it owns its physics).
--     MovementGuard is told a dash is coming (SonicBurstUntil, SonicBurstGuardMultiplier)
--     so a real burst is never taken for a teleport and still counts the stages it crosses.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.AbilitySonicBurstEnabled ~= true then
	return
end
local WinsMath = require(Shared:WaitForChild("WinsMath"))
local SonicBurstMath = require(Shared:WaitForChild("SonicBurstMath"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local RateLimiter = require(Services:WaitForChild("ServerRateLimiter"))

local UPGRADE = tostring(Config.AbilitySonicBurstUpgradeName or "SonicBurst")
local EQUIPPED_MARKER = "__AbilityEquipped_" .. UPGRADE
local BASE_COST = math.max(0, math.floor(tonumber(Config.AbilitySonicBurstWinsCost) or 500000000))
local GAMEPASS_ID = tonumber(Config.AbilitySonicBurstGamePassId) or 1985906818
local COOLDOWN = SonicBurstMath.Cooldown(Config)
local CHARGE = SonicBurstMath.Charge(Config)
local DASH = SonicBurstMath.Dash(Config)
-- Latency: a request may arrive a little before the owner's own cooldown ran out here.
local COOLDOWN_SLACK = 0.3

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name)
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local Action = remote("SonicBurstAction")
local Update = remote("SonicBurstUpdate")

local busy = {}
local lastFiredAt = {}
-- When each player's current charge began (os.clock), while they charge.
local chargingSince = {}
local MAX_CHARGE_SECONDS = 30

local function flag(player, name)
	local data = player:FindFirstChild("SpeedsterData")
	local owned = data and data:FindFirstChild("OwnedUpgrades")
	local value = owned and owned:FindFirstChild(name)
	return value ~= nil and value:IsA("BoolValue") and value.Value == true
end

local function owns(player)
	return flag(player, UPGRADE)
end

local function isEquipped(player)
	return owns(player) and flag(player, EQUIPPED_MARKER)
end

-- The one price: what the card quotes and what the purchase charges.
local function winsCost(player)
	local multiplier
	if type(_G.SpeedsterGetPermanentWinsMultiplier) == "function" then
		local ok, value = pcall(_G.SpeedsterGetPermanentWinsMultiplier, player)
		if ok then
			multiplier = value
		end
	end
	if type(multiplier) ~= "number" then
		return WinsMath.GetProgressionPriceFor(BASE_COST, player, Config.ProgressionPriceMultiplierExponent)
	end
	return WinsMath.GetProgressionPrice(BASE_COST, multiplier, Config.ProgressionPriceMultiplierExponent)
end

local function syncAttributes(player)
	local owned, equipped = owns(player), isEquipped(player)
	if player:GetAttribute("SonicBurstOwned") ~= owned then
		player:SetAttribute("SonicBurstOwned", owned)
	end
	if player:GetAttribute("SonicBurstEquipped") ~= equipped then
		player:SetAttribute("SonicBurstEquipped", equipped)
	end
end

local function sendState(player, message)
	if not player.Parent then
		return
	end
	syncAttributes(player)
	Update:FireClient(player, {
		Kind = "State",
		Owned = owns(player),
		Equipped = isEquipped(player),
		WinsCost = winsCost(player),
		CooldownSeconds = COOLDOWN,
		Message = tostring(message or ""),
	})
end

local function commit(player, commands, fingerprint)
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return false, "Data is still loading"
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false, "Data is still loading"
	end
	local result = DataService.Commit(handle, {
		operationId = DataService.NewOperationId(),
		fingerprint = fingerprint,
		commands = commands,
	})
	if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
		if result.error and result.error.code == "InsufficientFunds" then
			return false, "Not Enough Wins"
		end
		return false, "Save is awaiting confirmation. Try again shortly."
	end
	return true
end

local function buy(player)
	if busy[player] then
		return
	end
	busy[player] = true
	local ran, ok, message = pcall(function()
		if owns(player) then
			return true, "Sonic Burst Owned"
		end
		local done, failure = commit(player, {
			{ kind = "PurchaseUpgrade", upgradeId = UPGRADE, cost = winsCost(player) },
			{ kind = "GrantUpgrade", upgradeId = EQUIPPED_MARKER },
		}, "sonic_burst_wins_purchase")
		return done, if done then "Sonic Burst Purchased & Equipped!" else failure
	end)
	busy[player] = nil
	if not ran then
		warn("[SonicBurst] Purchase failed: " .. tostring(ok))
	end
	sendState(player, if ran then message else "Purchase could not be confirmed. Try again shortly.")
end

local function grantAndEquipSonicBurst(player, reason)
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return false, "Data is still loading"
	end
	local done, failure = commit(player, {
		{ kind = "GrantUpgrade", upgradeId = UPGRADE },
		{ kind = "GrantUpgrade", upgradeId = EQUIPPED_MARKER },
	}, reason or "sonic_burst_grant")
	if done then
		sendState(player, "Sonic Burst Purchased & Equipped!")
	end
	return done, failure
end
_G.SpeedsterGrantSonicBurst = grantAndEquipSonicBurst

local function setEquipped(player, equipped)
	if not owns(player) then
		return false, "Sonic Burst is not owned"
	end
	local ok, failure = commit(player, {
		{ kind = if equipped then "GrantUpgrade" else "RemoveUpgrade", upgradeId = EQUIPPED_MARKER },
	}, "sonic_burst_equip:" .. tostring(equipped))
	if not ok then
		return false, failure
	end
	return true, if equipped then "Sonic Burst Equipped" else "Sonic Burst Unequipped"
end

-- Alive, standing, not flying, not seated: a burst from anything else is refused.
local function readyCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	if character:GetAttribute("Ragdolled") == true or character:GetAttribute("Dead") == true then
		return nil
	end
	if player:GetAttribute("FlightAbilityActive") == true or player:GetAttribute("AdminFlying") == true then
		return nil
	end
	-- Update 4 (2026-09-25): no bursts in a race (queued in the arena, staged or racing).
	if player:GetAttribute("RaceActive") == true then
		return nil
	end
	if humanoid.Sit or humanoid.PlatformStand then
		return nil
	end
	return root
end

local function deny(player, reason, readyIn)
	Update:FireClient(player, { Kind = "Denied", Reason = reason, ReadyIn = readyIn })
end

-- The checks every charge and burst passes: equipped, off cooldown, on its feet.
local function refusal(player)
	if not isEquipped(player) then
		return "NotEquipped"
	end
	local since = os.clock() - (lastFiredAt[player] or -math.huge)
	if since < COOLDOWN - COOLDOWN_SLACK then
		return "Cooldown", COOLDOWN - since
	end
	if not readyCharacter(player) then
		return "NotReady"
	end
	return nil
end

local function startCharge(player)
	local reason, readyIn = refusal(player)
	if reason then
		deny(player, reason, readyIn)
		return
	end
	chargingSince[player] = os.clock()
	Update:FireAllClients({ Kind = "Charge", Player = player })
end

local function cancelCharge(player)
	if chargingSince[player] then
		chargingSince[player] = nil
		Update:FireAllClients({ Kind = "ChargeEnd", Player = player })
	end
end

local function fire(player, direction, charge)
	local since = chargingSince[player]
	chargingSince[player] = nil
	-- A burst is let go after a charge the server saw begin.
	if not since or os.clock() - since > MAX_CHARGE_SECONDS then
		deny(player, "NotCharging")
		Update:FireAllClients({ Kind = "ChargeEnd", Player = player })
		return
	end
	local reason, readyIn = refusal(player)
	if reason then
		deny(player, reason, readyIn)
		Update:FireAllClients({ Kind = "ChargeEnd", Player = player })
		return
	end
	local root = readyCharacter(player)
	local level = math.clamp(tonumber(charge) or 0, 0, 1)
	if level ~= level then
		level = 0
	end
	lastFiredAt[player] = os.clock()
	local flat = SonicBurstMath.FlatDirection(direction, root.CFrame.LookVector)
	local velocity = root.AssemblyLinearVelocity
	local speed = SonicBurstMath.ReferenceSpeed(player:GetAttribute("RealWalkSpeedSelected"), Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
	local serverNow = Workspace:GetServerTimeNow()
	-- MovementGuard: the dash may move this many times the walk speed until then.
	player:SetAttribute("SonicBurstGuardMultiplier", SonicBurstMath.GuardMultiplier(speed, Config, level))
	player:SetAttribute("SonicBurstUntil", serverNow + CHARGE + DASH + 0.75)
	player:SetAttribute("SonicBurstReadyAt", serverNow + COOLDOWN)
	Update:FireAllClients({
		Kind = "Burst",
		Player = player,
		Direction = flat,
		Speed = speed,
		Charge = level,
		At = serverNow,
	})
end

Action.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" or #action > 24 then
		return
	end
	if not RateLimiter.Allow(player, "SonicBurst" .. action, 0.1) then
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if action == "RequestState" then
		sendState(player)
	elseif action == "BuyWins" then
		buy(player)
	elseif action == "Equip" or action == "Unequip" then
		local _, message = setEquipped(player, action == "Equip")
		sendState(player, message)
	elseif action == "Charge" then
		startCharge(player)
	elseif action == "Cancel" then
		cancelCharge(player)
	elseif action == "Fire" then
		local data = if type(payload) == "table" then payload else {}
		fire(player, if typeof(data.Direction) == "Vector3" then data.Direction else nil, data.Charge)
	elseif action == "StudioGrant" and RunService:IsStudio() then
		-- Studio only: try the ability without the Wins.
		local ok, message = commit(player, {
			{ kind = "GrantUpgrade", upgradeId = UPGRADE },
			{ kind = "GrantUpgrade", upgradeId = EQUIPPED_MARKER },
		}, "sonic_burst_studio_grant")
		sendState(player, if ok then "Sonic Burst (Studio)" else message)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, purchaseSuccess)
	if purchaseSuccess and tonumber(purchasedPassId) == GAMEPASS_ID then
		if grantAndEquipSonicBurst(player, "sonic_burst_gamepass_purchase") then
			print("[SonicBurst] Sonic Burst GamePass granted to " .. player.Name)
		end
	end
end)

local function setupPlayer(player)
	task.spawn(function()
		for _ = 1, 120 do
			if not player.Parent then
				return
			end
			local data = player:FindFirstChild("SpeedsterData")
			if player:GetAttribute("DataLoaded") == true and data and data:FindFirstChild("OwnedUpgrades") then
				break
			end
			task.wait(0.25)
		end
		if not player.Parent then
			return
		end

		-- Check GamePass ownership on join
		if GAMEPASS_ID and GAMEPASS_ID > 0 then
			local ok, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
			end)
			if ok and ownsPass == true then
				grantAndEquipSonicBurst(player, "sonic_burst_gamepass_on_join")
			end
		end

		local owned = player.SpeedsterData:FindFirstChild("OwnedUpgrades")
		if owned then
			-- The profile's upgrades mirror into this folder; keep the attributes in step.
			owned.ChildAdded:Connect(function()
				syncAttributes(player)
			end)
			owned.ChildRemoved:Connect(function()
				syncAttributes(player)
			end)
		end
		sendState(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	task.defer(setupPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	lastFiredAt[player] = nil
	chargingSince[player] = nil
end)
