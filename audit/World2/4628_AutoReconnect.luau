local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local POS_STORE = DataStoreService:GetDataStore("SpeedsterEscape_ReconnectPos_v1")
local SAVE_INTERVAL = 30
local MAX_STALE_SECONDS = 600

local savedPositions = {}

local function positionKey(player)
	return "Pos_" .. tostring(player.UserId) .. "_" .. tostring(game.PlaceId)
end

local function serializeCFrame(cf)
	return {cf:GetComponents()}
end

local function deserializeCFrame(t)
	if type(t) ~= "table" or #t < 12 then
		return nil
	end
	return CFrame.new(unpack(t))
end

local function savePosition(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local data = {
		CFrame = serializeCFrame(root.CFrame),
		SavedAt = os.time(),
	}

	savedPositions[player.UserId] = data

	local ok, err = pcall(function()
		POS_STORE:SetAsync(positionKey(player), data)
	end)

	if not ok then
		warn("[AutoReconnect] Failed to save position for " .. player.Name .. ": " .. tostring(err))
	end
end

local function loadAndRestorePosition(player)
	local data = nil

	local cached = savedPositions[player.UserId]
	if cached and (os.time() - (cached.SavedAt or 0)) <= MAX_STALE_SECONDS then
		data = cached
	end

	if not data then
		local ok, result = pcall(function()
			return POS_STORE:GetAsync(positionKey(player))
		end)
		if ok and type(result) == "table" and result.CFrame then
			data = result
		end
	end

	if not data or not data.CFrame then
		return
	end

	if (os.time() - (data.SavedAt or 0)) > MAX_STALE_SECONDS then
		return
	end

	local targetCFrame = deserializeCFrame(data.CFrame)
	if not targetCFrame then
		return
	end

	local deadline = os.clock() + 15
	while player.Parent and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
		task.wait(0.1)
	end

	if not player.Parent then
		return
	end

	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end

	local root = character and character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	task.wait(0.2)

	if not player.Parent or not root.Parent then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	-- Notify MovementGuard so restoring a saved position is not treated
	-- as a teleport anomaly (progress is re-derived from that position).
	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadAndRestorePosition, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadAndRestorePosition, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePosition(player)
	savedPositions[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(savePosition, player)
		end
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	for _, player in ipairs(players) do
		task.spawn(savePosition, player)
	end
end)