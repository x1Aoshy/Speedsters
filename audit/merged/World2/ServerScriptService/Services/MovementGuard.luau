local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StageTeleportService = require(script.Parent:WaitForChild("StageTeleportService"))

-- ============================================================================
--  MovementGuard
--
--  Server-side movement/progression guard used to gate win-pad rewards.
--  Reward pads may ONLY be claimed by characters whose server-observed
--  motion looks like a real run: continuous movement, bounded speed, and
--  ascending stage progress that advanced one stage at a time.
--
--  Why this is needed: the game previously trusted `Touched` alone. A
--  client-side teleport exploiter could place their character directly on
--  a reward pad (e.g. the 700k Winstage1 pad) and claim it endlessly, and
--  even re-skip the whole course, because progression attributes were
--  updated by the server purely from the (spoofed) position.
--
--  This module samples every character's root position on Heartbeat and:
--    * flags teleport anomalies (super-speed motion, single-frame pops,
--      out-of-order stage leaps) -> blocks all reward claims for a while
--      and freezes stage progress;
--    * advances each player's trusted `progress` ONLY when they are seen
--      cleanly reaching the next stage in order;
--    * pauses checks for a short window after a server-side teleport
--      (sanctioned via MovementGuard.Rebase), so legitimate skips,
--      win-pad returns, revives and reconnects are never penalized.
-- ============================================================================

local MovementGuard = {}

-- Legit top speed is far above a naive walk cap: the smooth speed curve
-- (RealWalkSpeedAtReference=300) x boost x confetti reaches ~1000+ studs/s,
-- the "instant movement" controller moves characters by setting positions
-- each frame, and free-fall from this map's high altitude (Y~37k) reaches
-- thousands of studs/s before the death plane. The 1500 ceiling flagged all
-- of that as a teleport anomaly and silently blocked every win-pad claim for
-- 45 s. Real client teleport exploits are still caught by the single-frame
-- position-pop check below (MAX_LEGIT_JUMP_DISTANCE), which cannot be
-- reached by any legit motion, so the speed ceiling only needs to cover the
-- legit range with headroom (100000 = the game's own safetyCapRealSpeed
-- reference used by the run controller).
local MAX_LEGIT_SPEED = 150000        -- studs/s
local MAX_LEGIT_JUMP_DISTANCE = 2500  -- single-sample pop distance
local JUMP_DT_LIMIT = 1.0             -- seconds (only strong when dt is small)
local ANOMALY_BLOCK_SECONDS = 45      -- reward claims blocked after an anomaly
local SANCTION_STEADY_SECONDS = 3     -- checks paused after a server teleport
local STAGE_AT_MARGIN = 170           -- studs from a stage center counts as "at stage"
local FINAL_PAD_COOLDOWN_SECONDS = if Config.IsWorld2Place == true
	then math.max(0, tonumber(Config.World2FinalPadCooldownSeconds) or 1.5) else 180

local states = setmetatable({}, { __mode = "k" })       -- [player] = state
local finalClaimAt = setmetatable({}, { __mode = "k" }) -- [player] = os.clock()

local function defaultState()
	return {
		progress = 1,
		lastPos = nil,
		lastAt = 0,
		steadyUntil = 0,
		suspiciousUntil = 0,
	}
end

local function nearestStageAtPosition(position)
	if typeof(position) ~= "Vector3" then
		return nil
	end
	local nearest, distance = StageTeleportService.GetNearestStage(position)
	if nearest and distance and distance <= STAGE_AT_MARGIN then
		return nearest
	end
	return nil
end

-- Samples one character. Returns true if an anomaly was detected.
-- Progress only advances by hitting the next stage in order while moving
-- cleanly; on anomaly the progress is frozen and claims are blocked.
local function advanceAlongSegment(player, state, root, from, to, dt)
	if type(StageTeleportService.GetStageReferencePosition) ~= "function" then return end
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local selected = tonumber(player:GetAttribute("RealWalkSpeedSelected")) or 0
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local speed = math.max(selected, humanoid and humanoid.WalkSpeed or 0)
	local multiplier = player:GetAttribute("IsBoosting") == true and (tonumber(Config.BoostWalkSpeedMultiplier) or 1.7) or 1
	if (tonumber(player:GetAttribute("ConfettiBoostExpire")) or 0) > os.time() then
		multiplier *= math.clamp(tonumber(player:GetAttribute("ConfettiSpeedMult")) or 2, 1, 4)
	end
	if player:GetAttribute("FlightAbilityActive") == true then multiplier = math.max(multiplier, 1.7) end
	-- A Sonic Burst dash (Core/Abilities/SonicBurstService) moves several times the walk
	-- speed for a moment; the server granted it, so its stages still count.
	if (tonumber(player:GetAttribute("SonicBurstUntil")) or 0) > Workspace:GetServerTimeNow() then
		multiplier *= math.clamp(tonumber(player:GetAttribute("SonicBurstGuardMultiplier")) or 1, 1, 8)
	end
	-- Never bridge checkpoint gaps using an unbounded teleport or a stale sample.
	if dt > 0.5 or delta.Magnitude > math.min(256, speed * multiplier * dt * 1.5 + 8) then return end
	local lengthSquared = delta:Dot(delta)
	if lengthSquared < 0.001 then return end
	local previousFraction = 0
	for stage = state.progress + 1, math.max(2, tonumber(Config.StageCount) or 10) do
		local center = StageTeleportService.GetStageReferencePosition(stage)
		if not center then break end
		local offset = Vector3.new(from.X - center.X, 0, from.Z - center.Z)
		local b = offset:Dot(delta)
		local c = offset:Dot(offset) - STAGE_AT_MARGIN * STAGE_AT_MARGIN
		local discriminant = b * b - lengthSquared * c
		if discriminant < 0 then break end
		local enter = math.max(0, (-b - math.sqrt(discriminant)) / lengthSquared)
		local leave = math.min(1, (-b + math.sqrt(discriminant)) / lengthSquared)
		local fraction = math.max(previousFraction, enter)
		if fraction > leave then break end
		state.progress = stage
		previousFraction = fraction
	end
end

local function samplePlayer(player, state, root, now)
	local pos = root.Position

	if state.lastPos == nil then
		state.lastPos = pos
		state.lastAt = now
		return false
	end

	local dt = math.max(0.0001, now - state.lastAt)
	local from = state.lastPos
	local dist = (pos - from).Magnitude
	local speed = dist / dt

	state.lastPos = pos
	state.lastAt = now

	local protected = now < state.steadyUntil

	local anomalous = false

	if not protected and speed > MAX_LEGIT_SPEED then
		anomalous = true
	end

	if not protected and dt < JUMP_DT_LIMIT and dist > MAX_LEGIT_JUMP_DISTANCE then
		anomalous = true
	end

	if not anomalous then
		advanceAlongSegment(player, state, root, from, pos, dt)
		local nearest, nearestDistance = StageTeleportService.GetNearestStage(pos)
		if nearest and nearestDistance and nearestDistance <= STAGE_AT_MARGIN then
			if nearest > state.progress + 1 then
				-- Leaped one or more stages without being seen moving through
				-- them in order - that is not how a real runner travels.
				-- Missing progress is not a fresh teleport every time the player
				-- stands still. CanClaim reports the checkpoint to recover at.
				state.missingStage = state.progress + 1
			elseif nearest > state.progress then
				state.progress = nearest
			end
		end
	end

	if anomalous then
		state.suspiciousUntil = now + ANOMALY_BLOCK_SECONDS
		return true
	end

	return false
end

-- (Re)initializes tracking for a freshly spawned character. The spawn
-- position is server-controlled, so blessing the nearest stage there is safe.
function MovementGuard.ResetForCharacter(player, character)
	local state = states[player]
	if not state then
		state = defaultState()
		states[player] = state
	end
	state.suspiciousUntil = 0
	state.steadyUntil = os.clock() + SANCTION_STEADY_SECONDS
	state.lastPos = nil
	state.lastAt = 0
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearest = nearestStageAtPosition(root and root.Position)
	state.progress = math.max(1, nearest or 1)
end

-- Marks a server-initiated teleport as legitimate. progressTarget may be a
-- stage number, or nil/"loose" to re-derive progress from the current
-- position (used by reconnect restoration).
function MovementGuard.Rebase(player, progressTarget)
	local state = states[player]
	if not state then
		state = defaultState()
		states[player] = state
	end
	state.suspiciousUntil = 0
	state.steadyUntil = os.clock() + SANCTION_STEADY_SECONDS
	state.lastPos = nil
	state.lastAt = 0
	if type(progressTarget) == "number" then
		state.progress = math.max(1, math.floor(progressTarget))
	else
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local nearest = StageTeleportService.GetNearestStage(root.Position)
			state.progress = math.max(1, nearest or 1)
		else
			state.progress = 1
		end
	end
end

function MovementGuard.IsBlocked(player)
	local state = states[player]
	if not state then
		return true -- fail closed
	end
	return os.clock() < state.suspiciousUntil
end

function MovementGuard.GetProgress(player)
	local state = states[player]
	return state and state.progress or 1
end

-- The single gate every reward pad must pass. Performs a live anomaly
-- re-check (so a teleport that lands on the pad the very same frame is
-- caught), verifies trusted stage progress, and checks the final-pad
-- hard cooldown without mutating state (pure query).
function MovementGuard.CanClaim(player, requiredProgress, isFinal, nowOverride)
	-- Studio exercises exactly the same validator as a live server.
	local now = type(nowOverride) == "number" and nowOverride or os.clock()
	local state = states[player]
	if not state then
		return false, "NotReady"
	end

	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and root.Parent then
		samplePlayer(player, state, root, now)
	end

	if now < state.suspiciousUntil then
		return false, "SuspiciousMovement", math.ceil(state.suspiciousUntil - now)
	end

	if state.progress < math.max(1, math.floor(tonumber(requiredProgress) or 1)) then
		return false, "MissingCheckpoint", state.progress + 1
	end

	if isFinal then
		local last = finalClaimAt[player]
		if last ~= nil and (now - last) < FINAL_PAD_COOLDOWN_SECONDS then
			return false, "Cooldown", math.ceil(FINAL_PAD_COOLDOWN_SECONDS - (now - last))
		end
	end

	return true
end

-- Explicitly records a successful final pad claim to start the cooldown.
function MovementGuard.RecordFinalClaim(player, nowOverride)
	if not player then
		return
	end
	local now = type(nowOverride) == "number" and nowOverride or os.clock()
	finalClaimAt[player] = now
end

MovementGuard.ConsumeFinalClaimCooldown = MovementGuard.RecordFinalClaim

function MovementGuard.FinalPadCooldownLeft(player, nowOverride)
	local last = finalClaimAt[player]
	if last == nil then
		return 0
	end
	local now = type(nowOverride) == "number" and nowOverride or os.clock()
	return math.max(0, FINAL_PAD_COOLDOWN_SECONDS - (now - last))
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		MovementGuard.ResetForCharacter(player, character)
	end)
	if player.Character then
		task.defer(function()
			MovementGuard.ResetForCharacter(player, player.Character)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	finalClaimAt[player] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and character.Parent
			and humanoid and humanoid.Health > 0
			and root and root:IsA("BasePart") and root.Parent
		then
			local state = states[player]
			if not state then
				state = defaultState()
				states[player] = state
				MovementGuard.ResetForCharacter(player, character)
			else
				if now - (state.lastSampledAt or 0) >= 0.1 then
					state.lastSampledAt = now
					samplePlayer(player, state, root, now)
				end
			end
		end
	end
end)

-- Global hook so scripts that deliberately avoid require()-ing this module
-- (e.g. StageTeleportService, AutoReconnect) can still notify us.
_G.VortexMovementGuardRebase = function(player, progressTarget)
	local ok, err = pcall(function()
		MovementGuard.Rebase(player, progressTarget)
	end)
	if not ok then
		warn("[MovementGuard] Rebase hook failed: " .. tostring(err))
	end
end

return MovementGuard
