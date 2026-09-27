-- A paid stage trip is one durable debit followed by one durable completion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WinsMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinsMath"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local StageTeleportService = require(Services:WaitForChild("StageTeleportService"))
local WORLD = Config.IsWorld2Place == true and 2 or 1
local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name)
	local existing = Remotes:FindFirstChild(name)
	if existing then return existing end
	local result = Instance.new("RemoteEvent")
	result.Name = name
	result.Parent = Remotes
	return result
end
local TeleportAction = remote("TeleportAction")
local TeleportUpdate = remote("TeleportUpdate")
local optionsByStage, lastActionAt, trips = {}, {}, {}
for _, option in ipairs(Config.TeleportStageOptions or {}) do
	local stage = tonumber(option.Stage)
	if stage and stage == stage and stage % 1 == 0 and stage >= 1 and stage <= STAGE_COUNT then
		optionsByStage[stage] = option
	end
end
local function sameSession(player, handle)
	local current = DataService.GetHandle(player.UserId)
	return player.Parent == Players and current and current.sessionId == handle.sessionId
		and current.generation == handle.generation and current.userId == handle.userId
end
-- A trip lands the player beside that stage's Win and x2 pads, so it is priced against what
-- those pads pay this player right now: every Wins multiplier RewardPadClaims applies (the same
-- resolver, so the same number) and the x2 pad when it pays them double. The damped ladder price
-- used before (base * permanent ^ 0.5) fell below the pad's payout from the x4 rung up, or with
-- the x2 pads pass, VIP, a potion or a server boost alone, and players looped
-- teleport -> pad -> teleport for free Wins. See Shared.WinsMath.GetStageTripPrice.
local function currentCosts(player)
	local resolve = _G.SpeedsterGetWinsMultiplier
	if type(resolve) ~= "function" then resolve = _G.SpeedsterGetPermanentWinsMultiplier end
	local multiplier = type(resolve) == "function" and resolve(player) or 1
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier == math.huge then return {}, 1 end
	local doublePads = WinsMath.OwnsDoublePads(player)
	local costs = {}
	for stage, option in pairs(optionsByStage) do
		local baseCost = tonumber(option.WinsCost)
		local cost = baseCost and WinsMath.GetStageTripPrice(baseCost, multiplier, doublePads)
		if cost and cost == cost and cost > 0 and cost <= 9007199254740991 then costs[stage] = cost end
	end
	return costs, multiplier
end
local function sendUpdate(player, message, success, stage)
	if player.Parent ~= Players then return end
	local handle = DataService.GetHandle(player.UserId)
	local view = handle and DataService.Inspect(handle)
	local wins = view and view.ok and view.value.profile.Wins or 0
	local costs, multiplier = currentCosts(player)
	TeleportUpdate:FireClient(player, { Wins = wins, Costs = costs, WinsMultiplier = multiplier,
		Message = tostring(message), Success = success == true, Stage = stage })
end
local function request(id, phase, command)
	return { operationId = "stage-trip:" .. id .. ":" .. phase,
		fingerprint = "stage-trip:" .. id .. ":" .. phase, commands = { command } }
end
local function commitTrip(player, state, transaction, nextStep)
	if trips[player] ~= state or not sameSession(player, state.handle) then
		if trips[player] == state then trips[player] = nil end
		return
	end
	local ok, result = pcall(DataService.Commit, state.handle, transaction)
	if ok and result and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
		nextStep()
	elseif not ok or (result and result.kind == "Pending") then
		-- An uncertain write must retain both its identity and the per-player lock.
		task.delay(2, commitTrip, player, state, transaction, nextStep)
	else
		trips[player] = nil
		local insufficient = result and result.error and result.error.code == "InsufficientFunds"
		sendUpdate(player, insufficient and ("Not Enough Wins (Need " .. tostring(state.trip.cost) .. " Wins)")
			or "Stage travel could not be saved. Please try again.", false, state.trip.stage)
	end
end
local function completeTrip(player, state)
	if not sameSession(player, state.handle) then trips[player] = nil return end
	local trip = state.trip
	local moved, reason = false, "Stage belongs to another world"
	-- A trip found pending after a reconnect was priced somewhere else: World 3 shares world
	-- code 1 with World 1 in the saved record, and a World 1 trip costs a fraction of World 3's.
	-- It is only honoured at this place's price or more; otherwise its exact cost goes back.
	local fairlyPaid = true
	if state.recovered then
		local price = currentCosts(player)[trip.stage]
		fairlyPaid = price ~= nil and trip.cost >= price
		if not fairlyPaid then reason = "That stage travel belongs to another world; Wins refunded" end
	end
	if trip.world == WORLD and fairlyPaid then
		local ok, result, why = pcall(StageTeleportService.TeleportPlayer, player, trip.stage)
		moved = ok and result == true
		reason = ok and why or tostring(result)
	end
	local finish = request(trip.id, "finish", { kind = "FinishStageTeleport", id = trip.id, refund = not moved })
	commitTrip(player, state, finish, function()
		trips[player] = nil
		sendUpdate(player, moved and ("Teleported to Stage " .. tostring(trip.stage))
			or (reason or "Stage is not ready; Wins refunded"), moved, trip.stage)
	end)
end
local function recoverPending(player)
	if trips[player] or player:GetAttribute("DataLoaded") ~= true then return false end
	local handle = DataService.GetHandle(player.UserId)
	local view = handle and DataService.Inspect(handle)
	local pending = view and view.ok and view.value.profile.PendingStageTeleport
	if not pending then return false end
	local state = { handle = handle, trip = pending, recovered = true }
	trips[player] = state
	-- After reconnect, complete the already paid trip in this world; a different
	-- world returns exactly its stored cost. No reward multiplier enters a refund.
	task.spawn(function()
		local deadline = os.clock() + 10
		while sameSession(player, handle) and os.clock() < deadline do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then break end
			task.wait(0.1)
		end
		completeTrip(player, state)
	end)
	return true
end
TeleportAction.OnServerEvent:Connect(function(player, action, requestedStage, displayedCost)
	if (action ~= "Wins" and action ~= "Quote") or trips[player] then return end
	local now = os.clock()
	if now - (lastActionAt[player] or -math.huge) < 0.35 then return end
	lastActionAt[player] = now
	if action == "Quote" then sendUpdate(player, "", false, 0) return end
	if type(requestedStage) ~= "number" or requestedStage ~= requestedStage or requestedStage % 1 ~= 0 then return end
	local option = optionsByStage[requestedStage]
	if not option then sendUpdate(player, "That stage is not available yet", false, requestedStage) return end
	if player:GetAttribute("DataLoaded") ~= true then sendUpdate(player, "Your data is still loading", false, requestedStage) return end
	if recoverPending(player) then return end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then sendUpdate(player, "Your data is still loading", false, requestedStage) return end
	local costs = currentCosts(player)
	local cost = costs[requestedStage]
	if not cost then sendUpdate(player, "Stage price is unavailable", false, requestedStage) return end
	if displayedCost~=cost then sendUpdate(player,"Price updated. Select the stage again to confirm.",false,requestedStage);return end
	local trip = { id = DataService.NewOperationId(), world = WORLD, stage = requestedStage, cost = cost }
	local state = { handle = handle, trip = trip }
	trips[player] = state
	local begin = request(trip.id, "begin", { kind = "BeginStageTeleport", id = trip.id, world = WORLD, stage = trip.stage, cost = cost })
	commitTrip(player, state, begin, function() completeTrip(player, state) end)
end)
local function setupPlayer(player)
	-- The price follows every multiplier the pads pay with; tell an open panel when one moves.
	for _, name in { "PermanentWinsMultiplier", "VIPWinsMultiplier", "PotionWinsMultiplier", "PotionWinsExpireUnix",
		"ConfettiWinMult", "ConfettiBoostExpire", "DoubleWinsPadUnlocked", "TwoXVictoryOwned" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute("DataLoaded") == true and not trips[player] then sendUpdate(player, "", false, 0) end
		end)
	end
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function() recoverPending(player) end)
	if player:GetAttribute("DataLoaded") == true then task.defer(recoverPending, player) end
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
for _, name in { "ServerWinsBoostExpiresUnix", "ServerWinsBoostMultiplier" } do
	game:GetService("Workspace"):GetAttributeChangedSignal(name):Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true and not trips[player] then sendUpdate(player, "", false, 0) end
		end
	end)
end
Players.PlayerRemoving:Connect(function(player) lastActionAt[player] = nil trips[player] = nil end)
