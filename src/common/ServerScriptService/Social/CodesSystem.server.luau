                         
                                                                                 
                                                                             

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function ensureRemote(name)
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

local Request = ensureRemote("CodesRequest")
local Update = ensureRemote("CodesUpdate")

local CodesCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CodesCatalog"))

local busy = {}
local lastRequestAt = {}

local function normalizeCode(value)
	return CodesCatalog.Normalize(value)
end

local function getOwnedUpgrades(player)
	local data = player:FindFirstChild("SpeedsterData")
	return data and data:FindFirstChild("OwnedUpgrades")
end

local function hasClaimed(player, markerName)
	local owned = getOwnedUpgrades(player)
	local marker = owned and owned:FindFirstChild(markerName)
	return marker ~= nil and marker:IsA("BoolValue") and marker.Value == true
end

local function fireResult(player, success, message)
	if player.Parent == Players then
		Update:FireClient(player, {
			Success = success == true,
			Message = tostring(message or ""),
		})
	end
end

local function waitForGrantFunctions()
	local deadline = os.clock() + 8
	while os.clock() < deadline do
		if type(_G.SpeedsterGrantExactStat) == "function"
			and type(_G.SpeedsterUnlockUpgrade) == "function"
			and type(_G.SpeedsterSavePlayer) == "function"
		then
			return _G.SpeedsterGrantExactStat, _G.SpeedsterUnlockUpgrade, _G.SpeedsterSavePlayer
		end
		task.wait(0.05)
	end
	return nil, nil, nil
end

local function snapshotStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local speed = leaderstats and leaderstats:FindFirstChild("Speed")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	local data = player:FindFirstChild("SpeedsterData")
	local rawSpeed = data and data:FindFirstChild("RawSpeed")
	if not speed or not wins or not rawSpeed then
		return nil
	end
	return {
		Speed = speed,
		Wins = wins,
		RawSpeed = rawSpeed,
		OldSpeed = speed.Value,
		OldWins = wins.Value,
		OldRawSpeed = rawSpeed.Value,
		OldCarry = player:GetAttribute("SpeedCarry") or 0,
	}
end

local function rollbackStats(player, speedDelta, winsDelta)
	local leaderstats = player:FindFirstChild("leaderstats")
	local data = player:FindFirstChild("SpeedsterData")
	local speed = leaderstats and leaderstats:FindFirstChild("Speed")
	local rawSpeed = data and data:FindFirstChild("RawSpeed")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")

	if speedDelta and speedDelta > 0 then
		if rawSpeed then
			rawSpeed.Value = math.max(0, rawSpeed.Value - speedDelta)
		end
		if speed then
			speed.Value = math.max(0, speed.Value - speedDelta)
		end
		if type(_G.SpeedsterApplyWalkSpeed) == "function" then
			_G.SpeedsterApplyWalkSpeed(player)
		end
	end

	if winsDelta and winsDelta > 0 and wins then
		wins.Value = math.max(0, wins.Value - winsDelta)
	end
end

local function redeemPotionCode(player, definition, finish, unlockUpgrade, savePlayer)
	local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))
	local durationMinutes = definition.Potion.DurationMinutes or 10
	local multiplier = definition.Potion.Multiplier
	local result
	if definition.Potion.Type == "Wins" then
		result = PotionServer.GrantWinsPotion(player, durationMinutes, multiplier)
	else
		result = PotionServer.GrantSpeedPotion(player, durationMinutes, multiplier)
	end
	if not result then
		finish(false, "Reward data is not ready. Try again.")
		return
	end

	unlockUpgrade(player, definition.Marker)
	task.defer(savePlayer, player, "code_redeem_" .. definition.Marker)

	result.Notify()
	local potionLabel = (definition.Potion.Type == "Wins" and "Wins Potion" or "Speed Potion")
	finish(true, "Successfully redeemed! " .. tostring(durationMinutes) .. " minute " .. potionLabel .. "!")
end

local function calculateProportionalRewards(player: Player, handle: any, DataService: any): (number, number)
	local inspectRes = handle and DataService.Inspect(handle)
	local profile = (inspectRes and inspectRes.ok and inspectRes.value.profile) or {}
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or profile.Rebirths or 0
	local curSpeed = tonumber(player:GetAttribute("RawSpeed")) or profile.Speed or 1
	local curWins = profile.Wins or tonumber(player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins") and player.leaderstats.Wins.Value) or 0

	local baseSpeed = 500000
	local baseWins = 15000

	local proportionalSpeed = math.max(baseSpeed, math.floor(curSpeed * 0.20) + (rebirths * 250000))
	local proportionalWins = math.max(baseWins, math.floor(curWins * 0.15) + (rebirths * 10000))

	proportionalSpeed = math.min(1e14, proportionalSpeed)
	proportionalWins = math.min(1e9, proportionalWins)

	return proportionalSpeed, proportionalWins
end

local dynamicCodes
local function resolveCode(submitted)
	local definition=CodesCatalog.Get(submitted)
	if definition then return definition end
	if not dynamicCodes then
		local ok,store=pcall(function() return game:GetService("DataStoreService"):GetDataStore("AdminAbuseCodes_v1") end)
		if not ok then return nil,"unavailable" end
		dynamicCodes=require(ServerScriptService.Services.DynamicCodeDefinitions).new(store)
	end
	return dynamicCodes:Get(submitted)
end

local function performRedeem(player: Player, submittedCode: string, forceClaim: boolean?, senderAdminName: string?, eventId: string?): (boolean, string)
	if type(submittedCode)~="string" or #submittedCode>64 then return false,"Invalid code." end
	local definition,lookupError = resolveCode(submittedCode)
	if not definition then
		-- Update 4 (2026-09-25): a code this window does not know may be the Community code
		-- (Social/CommunityRewardService), so typing it here works too. That service answers
		-- (its own reward, policy check and wrong-code limit) and tells the player itself.
		local community = _G.SpeedsterRedeemCommunityCode
		if not forceClaim and type(community) == "function" then
			local ok, granted, message = pcall(community, player, submittedCode)
			if ok and granted == true then
				fireResult(player, true, message)
				return true, tostring(message or "Successfully redeemed!")
			end
			if ok and lookupError ~= "unavailable" and type(message) == "string" and message ~= "" then
				return false, message
			end
		end
		return false, lookupError=="unavailable" and "Code service is unavailable. Try again shortly." or "Invalid code."
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return false, "Your data is still loading. Try again."
	end
	if not forceClaim and hasClaimed(player, definition.Marker) then
		return false, "AlreadyClaimed"
	end

	local DataService = require(ServerScriptService.Services.Data.DataService)
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false, "Your data is not ready."
	end

	local opId = if forceClaim
		then ("code_force:" .. definition.Marker .. ":" .. (type(eventId)=="string" and eventId or DataService.NewOperationId()))
		else ("code:" .. definition.Marker)

	local commands = { { kind = "GrantUpgrade", upgradeId = definition.Marker } }
	local rewards = {}

	if definition.Rebirths and definition.Rebirths > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Rebirths", amount = definition.Rebirths })
		table.insert(rewards, "+" .. tostring(definition.Rebirths) .. " Rebirths")
	end

	local grantSpeed = definition.Speed or 0
	local grantWins = definition.Wins or 0
	if definition.ProportionalRewards then
		local propSpeed, propWins = calculateProportionalRewards(player, handle, DataService)
		grantSpeed = math.max(grantSpeed, propSpeed)
		grantWins = math.max(grantWins, propWins)
	end

	if grantSpeed > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = grantSpeed })
		table.insert(rewards, "+" .. tostring(grantSpeed) .. " Speed")
	end
	if grantWins > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Wins", amount = grantWins })
		table.insert(rewards, "+" .. tostring(grantWins) .. " Wins")
	end

	local potionsList = {}
	if definition.Potions then
		for _, pot in ipairs(definition.Potions) do
			table.insert(potionsList, pot)
		end
	elseif definition.Potion then
		table.insert(potionsList, definition.Potion)
	end

	for _, potion in ipairs(potionsList) do
		local kind = if potion.Type == "Wins" then "WinsPotion" else "SpeedPotion"
		local mins = potion.DurationMinutes or 10
		local mult = potion.Multiplier or 2
		table.insert(commands, { kind = "GrantBuff", grant = { kind = kind, addedSeconds = mins * 60, multiplier = mult } })
		table.insert(rewards, "+" .. tostring(mins) .. "m 2x " .. (if potion.Type == "Wins" then "Wins" else "Speed"))
	end

	if definition.FlightMinutes and definition.FlightMinutes > 0 then
		local flightMins = definition.FlightMinutes
		table.insert(commands, {
			kind = "GrantBuff",
			grant = {
				kind = "TemporaryFlight",
				addedSeconds = flightMins * 60,
			},
		})
		table.insert(rewards, "+" .. tostring(flightMins) .. "m Flight")
	end

	local result = DataService.Commit(handle, {
		operationId = opId,
		receiptId = opId,
		fingerprint = opId,
		commands = commands,
	})
	if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
		return false, "Your reward is awaiting save confirmation. Try again shortly."
	end

	if definition.FlightMinutes and definition.FlightMinutes > 0 then
		-- GrantBuff and equipment markers were committed together above; projection owns the timer.
		if type(_G.SpeedsterRefreshAbilityShop) == "function" then
			_G.SpeedsterRefreshAbilityShop(player, "Flight equipped for " .. tostring(definition.FlightMinutes) .. "m!")
		end
	end

	local rewardStr = table.concat(rewards, ", ")
	local msg
	if senderAdminName and senderAdminName ~= "" then
		msg = "🎁 Admin " .. senderAdminName .. " activated code [" .. submittedCode .. "] for you! (" .. rewardStr .. ")"
	elseif definition.CustomMessage and definition.CustomMessage ~= "" then
		msg = definition.CustomMessage
	elseif rewardStr ~= "" then
		msg = "Successfully redeemed! " .. rewardStr
	else
		msg = "Successfully redeemed!"
	end

	fireResult(player, true, msg)
	return true, msg
end

_G.SpeedsterRedeemCode = performRedeem

local function redeem(player, submittedCode)
	if busy[player] then return end
	busy[player] = true
	local ok, msg = performRedeem(player, submittedCode, false, nil)
	if not ok and msg ~= "AlreadyClaimed" then
		fireResult(player, false, msg)
	elseif not ok and msg == "AlreadyClaimed" then
		fireResult(player, false, "Code already redeemed.")
	end
	busy[player] = nil
end

Request.OnServerEvent:Connect(function(player, action, payload)
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < 0.35 then
		return
	end
	lastRequestAt[player] = now
	if action == "Redeem" then
		redeem(player, payload)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	lastRequestAt[player] = nil
end)

print("[CodesSystem] V306KAC loaded. Stat codes use permanent one-time main-save markers; UPDATE2 grants a 10 minute Speed Potion; 7KCCU grants a 2x Wins Potion for 10 minutes.")
