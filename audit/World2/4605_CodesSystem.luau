                         
                                                                                 
                                                                             

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

local function redeem(player, submittedCode)
	if busy[player] then return end
	busy[player] = true

	local function finish(success, message)
		busy[player] = nil
		fireResult(player, success, message)
	end

	local definition = CodesCatalog.Get(submittedCode)
	if not definition then
		finish(false, "Invalid code.")
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		finish(false, "Your data is still loading. Try again.")
		return
	end
	if hasClaimed(player, definition.Marker) then
		finish(false, "Code already redeemed.")
		return
	end

	local grantExactStat, unlockUpgrade, savePlayer = waitForGrantFunctions()
	if not grantExactStat or not unlockUpgrade or not savePlayer then
		finish(false, "Reward data is not ready. Try again.")
		return
	end

	local hasStats = (definition.Speed and definition.Speed > 0) or (definition.Wins and definition.Wins > 0)
	local snapshot = nil
	if hasStats then
		snapshot = snapshotStats(player)
		if not snapshot then
			finish(false, "Reward data is not ready. Try again.")
			return
		end
	end

	local speedOk, speedDelta = true, 0
	if definition.Speed and definition.Speed > 0 then
		speedOk, speedDelta = grantExactStat(player, "Speed", definition.Speed)
	end

	local winsOk, winsDelta = true, 0
	if speedOk and definition.Wins and definition.Wins > 0 then
		winsOk, winsDelta = grantExactStat(player, "Wins", definition.Wins)
	end

	if not speedOk or not winsOk then
		rollbackStats(
			player,
			(speedDelta and speedDelta > 0) and speedDelta or 0,
			(winsDelta and winsDelta > 0) and winsDelta or 0
		)
		finish(false, "Reward data is not ready. Try again.")
		return
	end

	local rewards = {}
	if definition.Speed and definition.Speed > 0 then
		table.insert(rewards, "+" .. tostring(definition.Speed) .. " Speed")
	end
	if definition.Wins and definition.Wins > 0 then
		table.insert(rewards, "+" .. tostring(definition.Wins) .. " Wins")
	end

	if definition.Potion then
		local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))
		local durationMinutes = definition.Potion.DurationMinutes or 10
		local multiplier = definition.Potion.Multiplier
		local potResult
		if definition.Potion.Type == "Wins" then
			potResult = PotionServer.GrantWinsPotion(player, durationMinutes, multiplier)
		else
			potResult = PotionServer.GrantSpeedPotion(player, durationMinutes, multiplier)
		end
		if not potResult then
			rollbackStats(
				player,
				(speedDelta and speedDelta > 0) and speedDelta or 0,
				(winsDelta and winsDelta > 0) and winsDelta or 0
			)
			finish(false, "Reward data is not ready. Try again.")
			return
		end
		potResult.Notify()
		local potionLabel = (definition.Potion.Type == "Wins" and "Wins Potion" or "Speed Potion")
		table.insert(rewards, "+" .. tostring(durationMinutes) .. "m " .. potionLabel)
	end

	unlockUpgrade(player, definition.Marker)
	task.defer(savePlayer, player, "code_redeem_" .. definition.Marker)

	local rewardStr = table.concat(rewards, " ")
	if rewardStr ~= "" then
		finish(true, "Successfully redeemed! " .. rewardStr)
	else
		finish(true, "Successfully redeemed!")
	end
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
