-- V306JQ World 2 Speed Force ability authority.
-- Server validates the 0.37s hold, chooses the next higher stage from the
-- player's nearest stage, temporarily removes the real character from gameplay,
-- and performs the authoritative teleport after the local-only cutscene.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true or Config.AbilitySpeedForceEnabled ~= true then
	return
end

local StageTeleport = require(script.Parent:WaitForChild("World2StageTeleportService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getOrCreateRemote(name)
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

local SpeedForceAction = getOrCreateRemote("SpeedForceAction")
local SpeedForceCutscene = getOrCreateRemote("SpeedForceCutscene")

local HOLD_SECONDS = math.max(0.25, tonumber(Config.AbilitySpeedForceHoldSeconds) or 0.37)
local SERVER_TIMEOUT = math.max(4, tonumber(Config.AbilitySpeedForceServerTimeoutSeconds) or 10.75)
local HIDDEN_Y_OFFSET = 3000

local holds = {}
local sessions = {}
local visualCache = {}

local function canUse(player)
	return player:GetAttribute("SpeedForceAbilityOwned") == true
		and player:GetAttribute("SpeedForceAbilityEquipped") == true
		and player:GetAttribute("EquippedAbility") == "SpeedForce"
		and player:GetAttribute("SpeedForceTransitionActive") ~= true
end

local function getCharacterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

local function cacheAndHideCharacter(player, character, humanoid, root)
	local cache = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		OriginalCFrame = character:GetPivot(),
		RootAnchored = root.Anchored,
		AutoRotate = humanoid.AutoRotate,
		PlatformStand = humanoid.PlatformStand,
		Objects = {},
	}

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") then
			cache.Objects[object] = {
				Transparency = object.Transparency,
				CanCollide = object.CanCollide,
				CanTouch = object.CanTouch,
				CanQuery = object.CanQuery,
			}
			object.Transparency = 1
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		elseif object:IsA("Decal") or object:IsA("Texture") then
			cache.Objects[object] = { Transparency = object.Transparency }
			object.Transparency = 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
			cache.Objects[object] = { Enabled = object.Enabled }
			object.Enabled = false
		end
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	character:PivotTo(cache.OriginalCFrame + Vector3.new(0, HIDDEN_Y_OFFSET, 0))
	visualCache[player] = cache
	return cache
end

local function restoreCharacter(player, fallbackToOriginal)
	local cache = visualCache[player]
	visualCache[player] = nil
	if not cache then return end

	local character = cache.Character
	local humanoid = cache.Humanoid
	local root = cache.Root
	if character and character.Parent then
		if fallbackToOriginal == true then
			pcall(function() character:PivotTo(cache.OriginalCFrame) end)
		end
		for object, state in pairs(cache.Objects) do
			if object and object.Parent then
				if object:IsA("BasePart") then
					object.Transparency = state.Transparency
					object.CanCollide = state.CanCollide
					object.CanTouch = state.CanTouch
					object.CanQuery = state.CanQuery
				elseif object:IsA("Decal") or object:IsA("Texture") then
					object.Transparency = state.Transparency
				elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
					object.Enabled = state.Enabled
				end
			end
		end
	end
	if root and root.Parent then
		root.Anchored = cache.RootAnchored == true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = cache.AutoRotate ~= false
		humanoid.PlatformStand = cache.PlatformStand == true
	end
end

local function clearSession(player, token)
	local session = sessions[player]
	if not session or (token and session.Token ~= token) then return nil end
	sessions[player] = nil
	holds[player] = nil
	player:SetAttribute("SpeedForceTransitionActive", false)
	return session
end

local function finishSession(player, token, source)
	local session = sessions[player]
	if not session or session.Token ~= token or session.Finished then return end
	session.Finished = true

	local character, humanoid, root = getCharacterParts(player)
	if not character or character ~= session.Character then
		clearSession(player, token)
		restoreCharacter(player, false)
		if player.Parent then SpeedForceCutscene:FireClient(player, "End", token, false, "Character changed") end
		return
	end

	-- Release the hidden character before the authoritative stage service pivots it.
	root.Anchored = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	local ok, reason
	if session.IsFinal then
		ok, reason = StageTeleport.TeleportToFinalWinStage(player)
	else
		ok, reason = StageTeleport.TeleportPlayer(player, session.TargetStage)
	end

	if ok then
		restoreCharacter(player, false)
	else
		restoreCharacter(player, true)
	end
	clearSession(player, token)
	if player.Parent then
		SpeedForceCutscene:FireClient(player, "End", token, ok == true, tostring(reason or source or ""))
	end
end

local function deny(player, reason)
	if player.Parent then
		SpeedForceCutscene:FireClient(player, "Denied", "", false, tostring(reason or "Speed Force unavailable"))
	end
end

local function beginSession(player)
	if not canUse(player) then deny(player, "Equip Speed Force first") return end
	if sessions[player] then deny(player, "Speed Force is already active") return end
	if player:GetAttribute("CrossPlaceTeleporting") == true then deny(player, "Teleport already in progress") return end
	local started = holds[player]
	if not started or os.clock() - started < (HOLD_SECONDS - 0.12) then
		deny(player, "Hold Space longer")
		return
	end
	holds[player] = nil

	local character, humanoid, root = getCharacterParts(player)
	if not character then deny(player, "Character is not ready") return end
	if humanoid.Sit then deny(player, "Stand up before using Speed Force") return end

	local nearestStage = StageTeleport.GetNearestStage(root.Position)
	if not nearestStage then deny(player, "Could not find the nearest stage") return end
	nearestStage = math.clamp(math.floor(nearestStage), 1, 10)
	local isFinal = nearestStage >= 10
	local targetStage = isFinal and 10 or (nearestStage + 1)

	local token = HttpService:GenerateGUID(false)
	local session = {
		Token = token,
		Character = character,
		NearestStage = nearestStage,
		TargetStage = targetStage,
		IsFinal = isFinal,
		Finished = false,
	}
	sessions[player] = session
	player:SetAttribute("SpeedForceTransitionActive", true)
	player:SetAttribute("FlightAbilityActive", false)
	player:SetAttribute("FlightAbilityPowered", false)
	if player:GetAttribute("IsBoosting") == true then
		player:SetAttribute("IsBoosting", false)
		if type(_G.SpeedsterApplyWalkSpeed) == "function" then _G.SpeedsterApplyWalkSpeed(player) end
	end
	-- Prevent pad/hazard reward races around the transition window.
	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + SERVER_TIMEOUT + 2)
	cacheAndHideCharacter(player, character, humanoid, root)
	SpeedForceCutscene:FireClient(player, "Start", token, isFinal and "Final" or tostring(targetStage), nearestStage)

	task.delay(SERVER_TIMEOUT, function()
		if player.Parent and sessions[player] == session and not session.Finished then
			finishSession(player, token, "server_timeout")
		end
	end)
end

SpeedForceAction.OnServerEvent:Connect(function(player, action, token)
	action = tostring(action or "")
	if action == "HoldBegin" then
		if canUse(player) and not sessions[player] then
			holds[player] = os.clock()
		else
			holds[player] = nil
		end
	elseif action == "HoldCancel" then
		holds[player] = nil
	elseif action == "Activate" then
		beginSession(player)
	elseif action == "Finish" then
		finishSession(player, tostring(token or ""), "client_finished")
	end
end)

local function setupPlayer(player)
	player:SetAttribute("SpeedForceTransitionActive", false)
	player.CharacterAdded:Connect(function()
		holds[player] = nil
		local oldSession = sessions[player]
		if oldSession then sessions[player] = nil end
		visualCache[player] = nil
		player:SetAttribute("SpeedForceTransitionActive", false)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	holds[player] = nil
	sessions[player] = nil
	visualCache[player] = nil
end)

print("[World2SpeedForce] V306JQ server active | 0.37s verified hold | extended-cutscene timeout | nearest stage + 1 | local cutscene handshake")
