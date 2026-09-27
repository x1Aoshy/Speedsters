                         
                                                                                 
                                                                             

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	return
end

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

local CODE_DEFINITIONS = {
	thankyousomuchfor20kvisits = {
		Marker = "Code_ThankYouSoMuchFor20kVisits_v1",
		Speed = 100000,
		Wins = 1000,
	},
	thankyousomuchfor777groupmembers = {
		Marker = "Code_ThankYouSoMuchFor777GroupMembers_v1",
		Speed = 100000,
		Wins = 1000,
	},
	reach87percentlike = {
		Marker = "Code_Reach87PercentLike_v1",
		Speed = 137000,
		Wins = 1770,
	},
	["5kccu"] = {
		Marker = "Code_5kCCU_v1",
		Speed = 100000,
		Wins = 25000,
	},
	["3kccu"] = {
		Marker = "Code_3kCCU_v1",
		Speed = 0,
		Wins = 10000,
	},
}

local busy = {}
local lastRequestAt = {}

local function normalizeCode(value)
	if type(value) ~= "string" or #value > 100 then
		return ""
	end
	return string.lower((value:gsub("%s+", "")))
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

local function rollback(player, snapshot)
	if snapshot.RawSpeed.Parent then snapshot.RawSpeed.Value = snapshot.OldRawSpeed end
	if snapshot.Speed.Parent then snapshot.Speed.Value = snapshot.OldSpeed end
	if snapshot.Wins.Parent then snapshot.Wins.Value = snapshot.OldWins end
	player:SetAttribute("SpeedCarry", snapshot.OldCarry)
	if type(_G.SpeedsterApplyWalkSpeed) == "function" then
		_G.SpeedsterApplyWalkSpeed(player)
	end
end

local function redeem(player, submittedCode)
	if busy[player] then return end
	busy[player] = true

	local function finish(success, message)
		busy[player] = nil
		fireResult(player, success, message)
	end

	local definition = CODE_DEFINITIONS[normalizeCode(submittedCode)]
	if not definition then
		finish(false, "Invalid Code")
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		finish(false, "Your data is still loading. Try again.")
		return
	end
	if hasClaimed(player, definition.Marker) then
		finish(false, "Code Already Claimed")
		return
	end

	local grantExactStat, unlockUpgrade, savePlayer = waitForGrantFunctions()
	local snapshot = snapshotStats(player)
	if not grantExactStat or not unlockUpgrade or not savePlayer or not snapshot then
		finish(false, "Reward data is not ready. Try again.")
		return
	end

	local speedOk = select(1, grantExactStat(player, "Speed", definition.Speed))
	local winsOk = speedOk and select(1, grantExactStat(player, "Wins", definition.Wins))
	if not speedOk or not winsOk then
		rollback(player, snapshot)
		finish(false, "Reward data is not ready. Try again.")
		return
	end

	unlockUpgrade(player, definition.Marker)
	local saved = savePlayer(player, "code_redeem_" .. definition.Marker, true) == true
	if not saved then
		local owned = getOwnedUpgrades(player)
		local marker = owned and owned:FindFirstChild(definition.Marker)
		if marker then marker:Destroy() end
		rollback(player, snapshot)
		finish(false, "Code could not be saved. Try again.")
		return
	end

	finish(true, "Code Redeemed! +" .. tostring(definition.Speed) .. " Speed +" .. tostring(definition.Wins) .. " Wins")
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

print("[CodesSystem] V306KAC loaded. Three case-insensitive exact-value codes use permanent one-time main-save markers.")
