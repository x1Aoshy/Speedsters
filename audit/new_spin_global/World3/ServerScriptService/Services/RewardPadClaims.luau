-- Shared by every reward pad: one outstanding claim per player, even while saving yields.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataService = require(script.Parent.Data.DataService)
local MovementGuard = require(script.Parent.MovementGuard)
local Service = {}
local claims = {}

local PadTouchService = require(script.Parent.PadTouchService)
local function characterAtPad(player, pad)
	return PadTouchService.IsAtPad(player, pad)
end

function Service.IsAtPad(player, pad)
	return characterAtPad(player, pad)
end

function Service.Claim(player, pad, reward, stage, isFinal, returnToStart, onGranted)
	if claims[player] or player:GetAttribute("DataLoaded") ~= true
		or os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
		then PadTouchService.RequestRetry(player, pad); return false end
	if not characterAtPad(player, pad) and not PadTouchService.ConsumeContact(player, pad) then return false end
	if type(reward) ~= "number" or reward ~= reward or reward <= 0 or reward == math.huge then return false end
	if not MovementGuard.CanClaim(player, stage, isFinal) then PadTouchService.RequestRetry(player, pad); return false end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then PadTouchService.RequestRetry(player, pad); return false end
	PadTouchService.ConsumeContact(player, pad)
	local state = { handle = handle }
	claims[player] = state
	local moved, returned, reason = pcall(returnToStart, player)
	-- Never pay if the return failed, including a destination accidentally inside this pad.
	if not moved or returned ~= true or characterAtPad(player, pad) then
		claims[player] = nil
		warn("[RewardPadClaims] Return failed for " .. player.Name .. ": " .. tostring(reason or returned))
		return false
	end
	-- One multiplier for every wins reward in the game (Shared.WinsMath, published
	-- by PlayerStatsBridge). Pads used to apply only the permanent multiplier, so
	-- VIP, potions and boosts silently paid less than the billboard advertised.
	local resolve = _G.SpeedsterGetWinsMultiplier
	if type(resolve) ~= "function" then resolve = _G.SpeedsterGetPermanentWinsMultiplier end
	local multiplier = type(resolve) == "function" and resolve(player) or 1
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier == math.huge then multiplier = 1 end
	local grantedAmount = math.floor(reward * multiplier)
	local opId = DataService.NewOperationId()
	state.request = {
		operationId = opId,
		fingerprint = "win-pad:" .. tostring(stage) .. ":" .. tostring(isFinal) .. ":" .. tostring(opId),
		commands = { { kind = "GrantExact", stat = "Wins", amount = grantedAmount } },
	}
	if isFinal then table.insert(state.request.commands, {kind="QuestProgress",metric="wins",amount=1}) end

	-- Immediate feedback at 0ms delay: update leaderstats, record claim, and run audio/visual effects instantly!
	if typeof(player.FindFirstChild) == "function" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local winsStat = leaderstats and leaderstats:FindFirstChild("Wins")
		if winsStat and winsStat:IsA("IntValue") then
			winsStat.Value += grantedAmount
		end
	end

	if isFinal then
		MovementGuard.RecordFinalClaim(player)
	end

	if player.Parent == Players and onGranted then
		local feedbackOk, feedbackError = pcall(onGranted, grantedAmount)
		if not feedbackOk then warn("[RewardPadClaims] Feedback: " .. tostring(feedbackError)) end
	end

	local function settle()
		if claims[player] ~= state then return end
		local ok, result = pcall(DataService.Commit, state.handle, state.request)
		if ok and result and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
			claims[player] = nil
		elseif not ok or (result and result.kind == "Pending") then
			-- Reuse this operation after an uncertain write. A new touch cannot mint another grant.
			local current = DataService.GetHandle(player.UserId)
			if player.Parent == Players and current and current.userId == state.handle.userId
				and current.sessionId == state.handle.sessionId and current.generation == state.handle.generation then
				if typeof(task) == "table" and task.delay then
					task.delay(2, settle)
				else
					claims[player] = nil
				end
			else claims[player] = nil end
		else
			claims[player] = nil
			warn("[RewardPadClaims] Claim rejected for " .. player.Name .. ": " .. tostring(result and result.kind))
		end
	end

	local taskSpawn = (typeof(task) == "table" and task.spawn) or function(fn) fn() end
	taskSpawn(settle)
	return true
end

Players.PlayerRemoving:Connect(function(player) claims[player] = nil end)
return Service
