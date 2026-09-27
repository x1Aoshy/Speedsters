         
                                                                        
                                                                                    
                                                                            
                                                          

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local DailyRewards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewards"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DailyLoginRequest = Remotes:FindFirstChild("DailyLoginRequest")
if not DailyLoginRequest then
	DailyLoginRequest = Instance.new("RemoteEvent")
	DailyLoginRequest.Name = "DailyLoginRequest"
	DailyLoginRequest.Parent = Remotes
end

local DailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")
if not DailyLoginUpdate then
	DailyLoginUpdate = Instance.new("RemoteEvent")
	DailyLoginUpdate.Name = "DailyLoginUpdate"
	DailyLoginUpdate.Parent = Remotes
end

local LegacyDataStore = DataStoreService:GetDataStore("SpeedsterEscape_DailyLogin_v1")

local states = {}
local claimInProgress = {}
local loadFailed = {}

local function safeNow()
	return os.time()
end

local function getLegacyKey(player)
	return "u_" .. tostring(player.UserId)
end

local function cloneArray(source)
	local copy = {}
	for _, value in ipairs(source or {}) do
		table.insert(copy, value)
	end
	return copy
end

local function cloneState(state)
	return {
		ClaimedDays = cloneArray(state.ClaimedDays),
		LastClaimAt = tonumber(state.LastClaimAt) or 0,
		LastClaimedDay = tonumber(state.LastClaimedDay) or 0,
		Cycle = tonumber(state.Cycle) or 1,
		NextDay = tonumber(state.NextDay) or 1,
		CanClaim = state.CanClaim == true,
		SecondsRemaining = tonumber(state.SecondsRemaining) or 0,
	}
end

local function defaultState()
	return {
		ClaimedDays = {},
		LastClaimAt = 0,
		LastClaimedDay = 0,
		Cycle = 1,
		NextDay = 1,
		CanClaim = true,
		SecondsRemaining = 0,
	}
end

local function cleanLoadedState(data)
	local state = defaultState()

	if type(data) == "table" then
		local seen = {}
		if type(data.ClaimedDays) == "table" then
			for _, dayValue in ipairs(data.ClaimedDays) do
				local day = math.floor(tonumber(dayValue) or 0)
				if day >= 1 and day <= DailyRewards.TotalDays and not seen[day] then
					seen[day] = true
					table.insert(state.ClaimedDays, day)
				end
			end
		end

		state.LastClaimAt = math.max(0, math.floor(tonumber(data.LastClaimAt) or 0))
		state.LastClaimedDay = math.clamp(
			math.floor(tonumber(data.LastClaimedDay) or 0),
			0,
			DailyRewards.TotalDays
		)
		state.Cycle = math.max(1, math.floor(tonumber(data.Cycle) or 1))
	end

	table.sort(state.ClaimedDays)

	                                                                             
	                                                                            
	if state.LastClaimedDay >= DailyRewards.TotalDays then
		state.LastClaimedDay = 0
		state.ClaimedDays = {}
		state.Cycle += 1
	end

	return state
end

-- M14 (2026-09-25): the next claim opens on the fixed 08:00 UTC day, 12-20 h after the last
-- one (Shared/DailyRewardsData.ClaimWindow), not a rolling 24 h.
local function recomputeClaimState(state)
	local canClaim, remaining = DailyRewards.ClaimWindow(tonumber(state.LastClaimAt) or 0, safeNow())
	state.SecondsRemaining = remaining
	state.CanClaim = canClaim
	state.NextDay = DailyRewards.GetNextDayAfterClaim(state.LastClaimedDay)
end

-- DailyCanClaim: the client opens the Daily by itself only when there is something to claim
-- (UpdateLogsController). Written only when it changes.
local function setCanClaimAttribute(player, canClaim)
	if player:GetAttribute("DailyCanClaim") ~= canClaim then
		player:SetAttribute("DailyCanClaim", canClaim)
	end
end

local function daysToCsv(days)
	local text = {}
	for _, day in ipairs(days or {}) do
		table.insert(text, tostring(day))
	end
	return table.concat(text, ",")
end

local function daysFromCsv(csv)
	local days = {}
	for token in string.gmatch(tostring(csv or ""), "[^,]+") do
		table.insert(days, tonumber(token))
	end
	return cleanLoadedState({ ClaimedDays = days }).ClaimedDays
end

local function stateFromMainAttributes(player)
	return cleanLoadedState({
		ClaimedDays = daysFromCsv(player:GetAttribute("DailyClaimedDaysCsv")),
		LastClaimAt = player:GetAttribute("DailyLastClaimAt"),
		LastClaimedDay = player:GetAttribute("DailyLastClaimedDay"),
		Cycle = player:GetAttribute("DailyRewardCycle"),
	})
end

local function syncStateToMainAttributes(player, state)
	player:SetAttribute("DailyClaimedDaysCsv", daysToCsv(state.ClaimedDays))
	player:SetAttribute("DailyLastClaimAt", state.LastClaimAt)
	player:SetAttribute("DailyLastClaimedDay", state.LastClaimedDay)
	player:SetAttribute("DailyRewardCycle", state.Cycle)
	player:SetAttribute("DailyStateReady", true)

	local setDaily = _G.SpeedsterSetDailyLoginState
	if type(setDaily) == "function" then
		setDaily(player, {
			ClaimedDays = cloneArray(state.ClaimedDays),
			LastClaimAt = tonumber(state.LastClaimAt) or 0,
			LastClaimedDay = tonumber(state.LastClaimedDay) or 0,
			Cycle = tonumber(state.Cycle) or 1,
		})
	end
end

local function buildClientState(state, message, claimSucceeded)
	recomputeClaimState(state)

	return {
		Rewards = DailyRewards.Rewards,
		ClaimedDays = cloneArray(state.ClaimedDays),
		LastClaimAt = state.LastClaimAt,
		LastClaimedDay = state.LastClaimedDay,
		NextDay = state.NextDay,
		CanClaim = state.CanClaim,
		SecondsRemaining = state.SecondsRemaining,
		DaySeconds = DailyRewards.DaySeconds,
		TotalDays = DailyRewards.TotalDays,
		Cycle = state.Cycle,
		Message = message,
		ClaimSucceeded = claimSucceeded == true,
		LoadFailed = false,
	}
end

local function fireFailure(player, message)
	setCanClaimAttribute(player, false)
	DailyLoginUpdate:FireClient(player, {
		Rewards = DailyRewards.Rewards,
		ClaimedDays = {},
		LastClaimAt = 0,
		LastClaimedDay = 0,
		NextDay = 1,
		CanClaim = false,
		SecondsRemaining = 0,
		DaySeconds = DailyRewards.DaySeconds,
		TotalDays = DailyRewards.TotalDays,
		Cycle = 1,
		Message = message or "Daily rewards are temporarily unavailable",
		ClaimSucceeded = false,
		LoadFailed = true,
	})
end

local function fireUpdate(player, message, claimSucceeded)
	local state = states[player]
	if state then
		local payload = buildClientState(state, message, claimSucceeded)
		setCanClaimAttribute(player, payload.CanClaim == true)
		DailyLoginUpdate:FireClient(player, payload)
	elseif loadFailed[player] then
		fireFailure(player)
	end
end

local function waitForMainData(player)
	local deadline = os.clock() + 30
	while player.Parent and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
		task.wait(0.1)
	end
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true
end

local function loadLegacyState(player)
	local lastError = nil
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return LegacyDataStore:GetAsync(getLegacyKey(player))
		end)
		if ok then
			return cleanLoadedState(result), nil
		end
		lastError = result
		if attempt < 3 then
			task.wait(1)
		end
	end
	return nil, lastError
end

local function loadPlayer(player)
	-- M14: a world change or the AFK idle rejoin is not a new visit: the Daily does not open
	-- by itself then (UpdateLogsController reads this).
	local okJoin, teleportData = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	local td = if okJoin and type(teleportData) == "table" then teleportData else {}
	player:SetAttribute("ArrivedByTeleport", td.FromWorld ~= nil or td.AfkModeResume == true)

	if not waitForMainData(player) then
		if player.Parent then
			loadFailed[player] = true
			fireFailure(player, "Your player data is still loading")
		end
		return
	end

	local state = nil
	local needsNormalizationSave = false
	if player:GetAttribute("DailyStateReady") == true then
		needsNormalizationSave = (tonumber(player:GetAttribute("DailyLastClaimedDay")) or 0)
			>= DailyRewards.TotalDays
		state = stateFromMainAttributes(player)
	elseif player:GetAttribute("SessionDataOnly") == true then
		                                                                          
		                                                                         
		state = defaultState()
		syncStateToMainAttributes(player, state)
	else
		local legacyState, legacyError = loadLegacyState(player)
		if not legacyState then
			loadFailed[player] = true
			warn("[DailyLoginSystem] Legacy migration load failed for " .. player.Name .. ": " .. tostring(legacyError))
			fireFailure(player)
			return
		end

		state = legacyState
		syncStateToMainAttributes(player, state)

		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) ~= "function" or savePlayer(player, "daily_state_migration", true) ~= true then
			player:SetAttribute("DailyStateReady", false)
			loadFailed[player] = true
			warn("[DailyLoginSystem] Could not safely migrate daily state for " .. player.Name)
			fireFailure(player)
			return
		end
	end

	recomputeClaimState(state)
	states[player] = state
	loadFailed[player] = nil
	syncStateToMainAttributes(player, state)
	setCanClaimAttribute(player, state.CanClaim == true)
	if needsNormalizationSave then
		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" then
			task.defer(savePlayer, player, "daily_cycle_normalization")
		end
	end

	task.defer(function()
		if player.Parent then
			fireUpdate(player)
		end
	end)
end

local function getRewardObjects(player, reward)
	if reward.Type == "Wins" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local wins = leaderstats and leaderstats:FindFirstChild("Wins")
		if not wins or not wins:IsA("IntValue") then
			return nil
		end
		return {
			Wins = wins,
			OldWins = wins.Value,
		}
	elseif reward.Type == "Speed" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local speed = leaderstats and leaderstats:FindFirstChild("Speed")
		local dataFolder = player:FindFirstChild("SpeedsterData")
		local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
		if not speed or not rawSpeed or not speed:IsA("NumberValue") or not rawSpeed:IsA("NumberValue") then
			return nil
		end
		return {
			Speed = speed,
			RawSpeed = rawSpeed,
			OldSpeed = speed.Value,
			OldRawSpeed = rawSpeed.Value,
			OldCarry = player:GetAttribute("SpeedCarry") or 0,
		}
	end
	return nil
end

local function applyReward(player, reward, transaction)
	if reward.Type == "Wins" then
		local addWins = _G.SpeedsterAddWins
		return type(addWins) == "function" and addWins(player, reward.Amount) == true
	elseif reward.Type == "Speed" then
		local addSpeed = _G.SpeedsterAddSpeed
		return type(addSpeed) == "function" and addSpeed(player, reward.Amount) == true
	end
	return false
end

local function rollbackReward(player, transaction)
	if transaction.Wins and transaction.Wins.Parent then
		transaction.Wins.Value = transaction.OldWins
	end
	if transaction.RawSpeed and transaction.RawSpeed.Parent then
		transaction.RawSpeed.Value = transaction.OldRawSpeed
	end
	if transaction.Speed and transaction.Speed.Parent then
		transaction.Speed.Value = transaction.OldSpeed
	end
	if transaction.OldCarry ~= nil then
		player:SetAttribute("SpeedCarry", transaction.OldCarry)
	end
	if _G.SpeedsterApplyWalkSpeed then
		_G.SpeedsterApplyWalkSpeed(player)
	end
end

local function claim(player)
	local state = states[player]
	if not state or loadFailed[player] or claimInProgress[player] then
		fireUpdate(player)
		return
	end
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DailyStateReady") ~= true then
		fireFailure(player, "Your player data is still loading")
		return
	end

	recomputeClaimState(state)
	if not state.CanClaim then
		fireUpdate(player)
		return
	end

	local day = DailyRewards.GetNextDayAfterClaim(state.LastClaimedDay)
	local reward = DailyRewards.GetReward(day)
	-- M15: only Speed/Wins need the replicated stat objects to be ready; Spin tickets and
	-- potions are profile commands only.
	local isStat = reward ~= nil and (reward.Type == "Wins" or reward.Type == "Speed")
	local transaction = if isStat then getRewardObjects(player, reward) else true
	if not reward or not transaction then
		fireUpdate(player, "Reward data is not ready")
		return
	end

	claimInProgress[player]=true
	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then claimInProgress[player]=nil;fireFailure(player,"Your data is not ready");return end
	local nextState=cloneState(state)
	if day>=DailyRewards.TotalDays then
		nextState.ClaimedDays={};nextState.LastClaimedDay=0;nextState.Cycle=math.max(1,nextState.Cycle+1)
	else
		table.insert(nextState.ClaimedDays,day);nextState.LastClaimedDay=day
	end
	nextState.LastClaimAt=safeNow()
	local amount=reward.Amount
	if reward.Type=="Wins" then
		amount*=(_G.SpeedsterGetPermanentWinsMultiplier(player) or 1)
	elseif reward.Type=="Speed" then
		local PotionServer=require(game:GetService("ServerScriptService").Services.PotionServer)
		local function attr(key) return tonumber(player:GetAttribute(key)) or 1 end
		amount*=(_G.SpeedsterGetTotalGainMultiplier(player) or 1)
			*(_G.SpeedsterGetSuitSpeedGainMultiplierForSkin(player:GetAttribute("EquippedSkin")) or 1)
			*(_G.SpeedsterGetRebirthSpeedGainMultiplier(player:GetAttribute("Rebirths") or 0) or 1)
			*attr("VIPSpeedGainMultiplier")*PotionServer.GetSpeedPotionMultiplier(player)*PotionServer.GetServerBoostMultiplier()
	end
	-- M15: the reward's command by type (Spin tickets and potions as QuestService pays them).
	local grant
	if reward.Type=="Wins" or reward.Type=="Speed" then
		grant={kind="GrantExact",stat=reward.Type,amount=amount}
	elseif reward.Type=="SpinTicket" then
		grant={kind="GrantSpinTickets",amount=math.max(1,math.floor(tonumber(reward.Amount) or 1))}
	elseif reward.Type=="PotionSpeed" or reward.Type=="PotionWins" then
		local minutes=math.max(1,math.floor(tonumber(reward.Amount) or 15))
		grant={kind="GrantBuff",grant={kind=if reward.Type=="PotionSpeed" then "SpeedPotion" else "WinsPotion",addedSeconds=minutes*60,multiplier=2,bottleType="Small"}}
	else
		claimInProgress[player]=nil;fireUpdate(player,"Reward data is not ready");return
	end
	local id="daily:"..state.Cycle..":"..day..":"..state.LastClaimAt
	local result=DataService.Commit(handle,{operationId=id,receiptId=id,fingerprint=id,commands={grant,{kind="SetDailyState",state=nextState}}})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		claimInProgress[player]=nil;fireUpdate(player,"Your reward is awaiting save confirmation. Try again shortly.");return
	end
	-- A retry may confirm yesterday's prepared state; use the authoritative result.
	local view=DataService.Inspect(handle)
	if view.ok then state=cleanLoadedState(view.value.profile.DailyLoginState);states[player]=state end
	recomputeClaimState(state)
	claimInProgress[player]=nil

	fireUpdate(player, "Claimed Day " .. tostring(day), true)
	print(
		"[DailyLoginSystem] "
			.. player.Name
			.. " claimed day "
			.. tostring(day)
			.. " reward "
			.. DailyRewards.GetRewardText(reward)
	)
end

local lastDailyRefreshAt = setmetatable({}, { __mode = "k" })
DailyLoginRequest.OnServerEvent:Connect(function(player, action)
	if action == "Claim" then
		claim(player)
	elseif action == "Refresh" then
		local now = os.clock()
		if now - (lastDailyRefreshAt[player] or 0) < 0.5 then return end
		lastDailyRefreshAt[player] = now
		fireUpdate(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	claimInProgress[player] = nil
	loadFailed[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			if states[player] then
				fireUpdate(player)
			end
		end
	end
end)

print("[DailyLoginSystem] V306HP loaded. Daily state/reward use one safe main-save transaction; only saved claims emit the one-shot success flag; no-catchup behavior preserved.")
