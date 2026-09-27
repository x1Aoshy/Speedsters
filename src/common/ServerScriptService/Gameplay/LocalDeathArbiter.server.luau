-- LocalDeathArbiter: judges deaths only the client saw (2026-09-25, H6).
--
-- The character's touch prediction (R15SpeedsterRun) kills the local humanoid on a lethal part
-- and sends LocalDeathClaim(hitPart, serverTime); its 2.5 s watchdog sends LocalDeathClaim(nil)
-- when the server still has not seen the death (a plain death since the final fix: the claim
-- with the part came first and was judged). Services/LocalDeathRules decides:
--   Kill   -> the server humanoid dies too: the usual death, revive offer and all;
--   Revive -> _G.SpeedsterOverruledRevive (SpeedProductPurchases): a fresh character at the
--             start of the player's stage, no offer, no stage lost;
--   Ignore -> the server already saw it.
-- This script creates the remote itself, so Bootstrap needs no change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Services = ServerScriptService:WaitForChild("Services")
local LocalDeathRules = require(Services:WaitForChild("LocalDeathRules", 10))
local RateLimiter = require(Services:WaitForChild("ServerRateLimiter", 10))
-- Creator Hub custom events (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local CLAIM_INTERVAL = 0.5 -- one claim per player per half second
local TELEMETRY_INTERVAL = 5 -- one custom event per player per 5 s
local REVIVE_INTERVAL = 3 -- one overruled respawn per player per 3 s (each is a LoadCharacter)
-- Overruled respawns are free (stage start, no revive offer), so a client could ask for them
-- whenever a death is coming. Past this many in the window the claim is a plain death instead,
-- what the watchdog's PlayerResetRequest used to be (2026-09-25; final fix: 3 per 3 min, was 4
-- a minute).
local REVIVE_BUDGET = 3
local REVIVE_BUDGET_WINDOW = 180
-- 2026-09-25 (final fix): an overruled respawn waits at least this long, so a death the server
-- sees right after the claim (a kill brick, the void, World 1's backstop) wins: the delayed
-- respawn below then does nothing and the normal death flow owns it. Protected claims (safe
-- zone, grace, race) never die on the server, so they respawn at once.
local REVIVE_MIN_DELAY = 0.5
local WORLD_LABEL = "W" .. (if Config.IsWorld2Place == true then "2" elseif Config.IsWorld3Place == true then "3" else "1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local claimRemote = remotes:FindFirstChild("LocalDeathClaim")
if claimRemote and not claimRemote:IsA("RemoteEvent") then
	claimRemote:Destroy()
	claimRemote = nil
end
if not claimRemote then
	claimRemote = Instance.new("RemoteEvent")
	claimRemote.Name = "LocalDeathClaim"
	claimRemote.Parent = remotes
end

-- character -> true once a claim for it was confirmed (Kill); character -> "Revive" once it
-- was overruled (its respawn is on the way: later claims for it are dropped).
local acceptedByCharacter = setmetatable({}, { __mode = "k" })
local overruledByCharacter = setmetatable({}, { __mode = "k" })
local lastReviveAt = {} -- [player] = os.clock() of the latest (or scheduled) overruled respawn
local reviveTimes = {} -- [player] = { os.clock() of each overruled respawn in the last minute }

Players.PlayerRemoving:Connect(function(player)
	lastReviveAt[player] = nil
	reviveTimes[player] = nil
end)

-- True (and counted) while the player has overruled respawns left this minute.
local function takeReviveBudget(player)
	local now = os.clock()
	local times = reviveTimes[player]
	if not times then
		times = {}
		reviveTimes[player] = times
	end
	for index = #times, 1, -1 do
		if now - times[index] >= REVIVE_BUDGET_WINDOW then
			table.remove(times, index)
		end
	end
	if #times >= REVIVE_BUDGET then
		return false
	end
	table.insert(times, now)
	return true
end

local customFields = (function()
	local ok, keys = pcall(function()
		return { Enum.AnalyticsCustomFieldKeys.CustomField01.Name, Enum.AnalyticsCustomFieldKeys.CustomField02.Name }
	end)
	return if ok then keys else { "CustomField01", "CustomField02" }
end)()

local function report(player, result, reason)
	if type(FunnelAnalytics.Event) ~= "function" or not RateLimiter.Allow(player, "LocalDeathTelemetry", TELEMETRY_INTERVAL) then
		return
	end
	FunnelAnalytics.Event(player, "LocalDeath_" .. result .. "_v2", 1, {
		[customFields[1]] = reason,
		[customFields[2]] = WORLD_LABEL,
	})
end

local function networkPing(player)
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	ping = if ok then tonumber(ping) else nil
	return if ping and ping == ping and ping >= 0 then ping else 0.1
end

local function isHazardCandidate(part)
	return typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(Workspace)
end

local function onClaim(player, hitPart, clientServerTime)
	if not RateLimiter.Allow(player, "LocalDeathClaim", CLAIM_INTERVAL) then
		return
	end
	local character = player.Character
	if not character or not character.Parent or overruledByCharacter[character] then
		return
	end
	-- Only a real BasePart in Workspace (not the claimer's own body) counts as evidence, and
	-- only a finite time; anything else is judged as a claim with no part.
	local part = if isHazardCandidate(hitPart) and not hitPart:IsDescendantOf(character) then hitPart else nil
	local clientTime = if type(clientServerTime) == "number" and clientServerTime == clientServerTime
		and math.abs(clientServerTime) ~= math.huge then clientServerTime else nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local poseProvider = (_G :: any).SpeedsterHazardPoseAt
	local ctx = {
		serverDead = humanoid == nil or humanoid.Health <= 0 or character:GetAttribute("Dead") == true,
		safeZone = player:GetAttribute("SafeZoneProtected") == true or character:GetAttribute("SafeZoneProtected") == true,
		teleportInvulnerable = player:GetAttribute("StageTeleportInvulnerable") == true,
		arrivalGrace = os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0),
		revivedJustNow = player:GetAttribute("RevivedJustNow") == true,
		raceActive = player:GetAttribute("RaceActive") == true,
		worldFrozen = Workspace:GetAttribute("AdminWorldFrozen") == true,
		part = part,
		claimAccepted = acceptedByCharacter[character] == true,
		poseAt = if type(poseProvider) == "function" then poseProvider else nil,
		now = Workspace:GetServerTimeNow(),
		clientTime = clientTime,
		rootPosition = if root and root:IsA("BasePart") then root.Position else nil,
		rootSpeed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0,
		rootVelocityY = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Y else 0,
		walkSpeed = tonumber(player:GetAttribute("RealWalkSpeedSelected")) or (if humanoid then humanoid.WalkSpeed else 16),
		boosting = player:GetAttribute("IsBoosting") == true,
		ping = networkPing(player),
	}
	local ok, result, reason = pcall(LocalDeathRules.Decide, ctx)
	if not ok then
		warn("[LocalDeathArbiter] " .. tostring(result))
		return
	end

	if result == "Revive" and not takeReviveBudget(player) then
		result, reason = "Kill", "ReviveBudget"
	end

	if result == "Kill" then
		acceptedByCharacter[character] = true
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		report(player, "Kill", reason)
	elseif result == "Revive" then
		overruledByCharacter[character] = true
		report(player, "Revive", reason)
		-- Each respawn is a LoadCharacter, so at most one per REVIVE_INTERVAL; a claim that comes
		-- sooner is respawned late, never dropped: the client's watchdog asks only once, and a
		-- dropped claim would leave the player lying dead for good.
		local waitSeconds = math.max(if reason == "Protected" then 0 else REVIVE_MIN_DELAY,
			(lastReviveAt[player] or -math.huge) + REVIVE_INTERVAL - os.clock())
		lastReviveAt[player] = os.clock() + waitSeconds
		task.delay(waitSeconds, function()
			if not player.Parent or player.Character ~= character then
				return -- left, or already respawned by something else
			end
			-- The server saw a real death meanwhile (World 1's contact remote, a kill brick): its
			-- own flow and revive offer own it now; a free respawn here would cancel that offer.
			local serverHumanoid = character:FindFirstChildOfClass("Humanoid")
			if (serverHumanoid and serverHumanoid.Health <= 0) or character:GetAttribute("Dead") == true then
				return
			end
			-- The server never saw this death, so LastReachedStage is still the player's stage
			-- (ReviveStageAtDeath may be left over from an older death).
			local stage = player:GetAttribute("LastReachedStage") or player:GetAttribute("ReviveStageAtDeath") or 1
			local revive = (_G :: any).SpeedsterOverruledRevive
			-- Without SpeedProductPurchases a plain respawn: never leave the client dead for good.
			local revived, message = if type(revive) == "function"
				then pcall(revive, player, stage)
				else pcall(player.LoadCharacter, player)
			if not revived then
				warn("[LocalDeathArbiter] overruled revive failed for " .. player.Name .. ": " .. tostring(message))
			end
		end)
	end
end

claimRemote.OnServerEvent:Connect(function(player, hitPart, clientServerTime)
	local ok, message = pcall(onClaim, player, hitPart, clientServerTime)
	if not ok then
		warn("[LocalDeathArbiter] " .. tostring(message))
	end
end)

print("[LocalDeathArbiter] active | client-only deaths: Kill / Revive at stage start / Ignore | " .. WORLD_LABEL)
