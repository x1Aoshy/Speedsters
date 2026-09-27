                         
                                                                                 
                                                                             

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

	local DataService=require(ServerScriptService.Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then finish(false,"Your data is not ready.");return end
	local commands={{kind="GrantUpgrade",upgradeId=definition.Marker}}
	local rewards={}
	for _,stat in {"Speed","Wins"} do
		if definition[stat] and definition[stat]>0 then
			table.insert(commands,{kind="GrantExact",stat=stat,amount=definition[stat]})
			table.insert(rewards,"+"..tostring(definition[stat]).." "..stat)
		end
	end
	if definition.Potion then
		local potion=definition.Potion
		local kind=if potion.Type=="Wins" then "WinsPotion" else "SpeedPotion"
		table.insert(commands,{kind="GrantBuff",grant={kind=kind,addedSeconds=(potion.DurationMinutes or 10)*60,multiplier=potion.Multiplier or 2}})
		table.insert(rewards,"+"..tostring(potion.DurationMinutes or 10).."m "..kind)
	end
	local result=DataService.Commit(handle,{operationId="code:"..definition.Marker,receiptId="code:"..definition.Marker,fingerprint=definition.Marker,commands=commands})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		finish(false,"Your reward is awaiting save confirmation. Try again shortly.");return
	end

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
