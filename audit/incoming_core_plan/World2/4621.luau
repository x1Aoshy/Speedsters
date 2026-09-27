-- Shared by every reward pad: one outstanding claim per player, even while saving yields.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataService = require(script.Parent.Data.DataService)
local MovementGuard = require(script.Parent.MovementGuard)
local Service = {}
local claims = {}

local function characterAtPad(player, pad)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not pad or not pad.Parent or not pad:IsDescendantOf(Workspace)
		or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	local half = pad.Size * 0.5
	return math.abs(offset.X) <= half.X + 14 and math.abs(offset.Z) <= half.Z + 14
		and math.abs(offset.Y) <= half.Y + math.max(14, humanoid.HipHeight + root.Size.Y + 5)
end

function Service.IsAtPad(player, pad)
	return characterAtPad(player, pad)
end

function Service.Claim(player, pad, reward, stage, isFinal, returnToStart, onGranted)
	if claims[player] or player:GetAttribute("DataLoaded") ~= true
		or os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
		or not characterAtPad(player, pad) then return false end
	if type(reward) ~= "number" or reward ~= reward or reward <= 0 or reward == math.huge then return false end
	if not MovementGuard.CanClaim(player, stage, isFinal) then return false end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then return false end
	local state = { handle = handle }
	claims[player] = state
	local moved, returned, reason = pcall(returnToStart, player)
	-- Never pay if the return failed, including a destination accidentally inside this pad.
	if not moved or returned ~= true or characterAtPad(player, pad) then
		claims[player] = nil
		warn("[RewardPadClaims] Return failed for " .. player.Name .. ": " .. tostring(reason or returned))
		return false
	end
	local multiplier = type(_G.SpeedsterGetPermanentWinsMultiplier) == "function"
		and _G.SpeedsterGetPermanentWinsMultiplier(player) or 1
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier == math.huge then multiplier = 1 end
	local opId = DataService.NewOperationId()
	state.request = {
		operationId = opId,
		fingerprint = "win-pad:" .. tostring(stage) .. ":" .. tostring(isFinal) .. ":" .. tostring(opId),
		commands = { { kind = "GrantExact", stat = "Wins", amount = math.floor(reward * multiplier) } },
	}
	local function settle()
		if claims[player] ~= state then return end
		local ok, result = pcall(DataService.Commit, state.handle, state.request)
		if ok and result and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
			claims[player] = nil
			if isFinal then MovementGuard.RecordFinalClaim(player) end
			if player.Parent == Players and onGranted then
				local feedbackOk, feedbackError = pcall(onGranted, state.request.commands[1].amount)
				if not feedbackOk then warn("[RewardPadClaims] Feedback: " .. tostring(feedbackError)) end
			end
		elseif not ok or (result and result.kind == "Pending") then
			-- Reuse this operation after an uncertain write. A new touch cannot mint another grant.
			local current = DataService.GetHandle(player.UserId)
			if player.Parent == Players and current and current.userId == state.handle.userId
				and current.sessionId == state.handle.sessionId and current.generation == state.handle.generation then
				task.delay(2, settle)
			else claims[player] = nil end
		else
			claims[player] = nil
			warn("[RewardPadClaims] Claim rejected for " .. player.Name .. ": " .. tostring(result and result.kind))
		end
	end
	settle()
	return true
end

Players.PlayerRemoving:Connect(function(player) claims[player] = nil end)
return Service
