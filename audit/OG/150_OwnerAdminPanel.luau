                                    
                                                                         
                                                                            

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local adminRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("OwnerAdminPanel")

local OWNER_USER_ID = 5113549114
local GLOBAL_TOPIC = "SpeedsterOwnerGrantV306GY"
local MAX_SAFE_INTEGER = 9007199254740991
local ACTION_COOLDOWN = 0.35
local SPAWN_COOLDOWN = 0.8
local MAX_ADMIN_SPAWNED_TREADMILLS = 25
local GLOBAL_MESSAGE_MAX_AGE = 180
local GLOBAL_COMMAND_DATASTORE_NAME = "SpeedsterEscape_OwnerGlobalCommands_v1"

local TREADMILLS = {
	{ Name = "Treadmill1_basic" },
	{ Name = "Treadmill2_fast" },
	{ Name = "Treadmill3_superfast" },
	{ Name = "Treadmill4_hyperspeed" },
	{ Name = "Treadmill5_insanespeed" },
}

local treadmillAllowed = {}
for _, entry in ipairs(TREADMILLS) do
	treadmillAllowed[entry.Name] = true
end

local SUFFIXES = {
	k = 1e3,
	m = 1e6,
	b = 1e9,
	t = 1e12,
	qa = 1e15,
	qi = 1e18,
	sx = 1e21,
	sp = 1e24,
	oc = 1e27,
	no = 1e30,
	dc = 1e33,
}

local runId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local lastActionAt = setmetatable({}, { __mode = "k" })
local panelOpenRequested = setmetatable({}, { __mode = "k" })
local lastSpawnAt = setmetatable({}, { __mode = "k" })
local treadmillTemplateCache = setmetatable({}, { __mode = "v" })
local processedMessages = {}
local processedMessageOrder = {}

local saveQueue = {}
local saveQueued = setmetatable({}, { __mode = "k" })
local saveWorkerRunning = false
local globalCommandStore = game:GetService("DataStoreService"):GetDataStore(GLOBAL_COMMAND_DATASTORE_NAME)

local spawnedFolder = Workspace:FindFirstChild("OwnerSpawnedTreadmills_V306GY")
if spawnedFolder and not spawnedFolder:IsA("Folder") then
	spawnedFolder = nil
end
if not spawnedFolder then
	spawnedFolder = Instance.new("Folder")
	spawnedFolder.Name = "OwnerSpawnedTreadmills_V306GY"
	spawnedFolder.Parent = Workspace
end

local function isOwner(player)
	return player ~= nil and player.UserId == OWNER_USER_ID
end

local function send(player, payload)
	if isOwner(player) and player.Parent == Players then
		adminRemote:FireClient(player, payload)
	end
end

local function sendResult(player, ok, message)
	send(player, {
		Type = "Result",
		Ok = ok == true,
		Message = tostring(message or ""),
	})
end

local function openPanel(player)
	if not isOwner(player) then
		return
	end
	send(player, {
		Type = "Open",
		Flying = player:GetAttribute("AdminFlying") == true,
	})
end

local function initializeOwnerState(player)
	if isOwner(player) then
		                                                                       
		player:SetAttribute("AdminFlying", false)
	end
end

local function validActionRate(player, action)
	local now = os.clock()
	local key = tostring(action or "")
	local state = lastActionAt[player]
	if not state then
		state = {}
		lastActionAt[player] = state
	end
	if now - (state[key] or -math.huge) < ACTION_COOLDOWN then
		return false
	end
	state[key] = now
	return true
end

local function parseAmount(raw, statName)
	local text = tostring(raw or ""):lower():gsub("[%s,_]", "")
	local amount = tonumber(text)
	if not amount then
		local numberText, suffix = text:match("^([%d%.]+)([%a]+)$")
		local multiplier = suffix and SUFFIXES[suffix]
		if numberText and multiplier then
			amount = tonumber(numberText) * multiplier
		end
	end

	if not amount
		or amount ~= amount
		or amount == math.huge
		or amount == -math.huge
		or amount <= 0
	then
		return nil, "Enter a positive amount, for example 50000, 2M, or 1e15"
	end

	if statName == "Wins" then
		amount = math.floor(amount)
		if amount < 1 or amount > MAX_SAFE_INTEGER then
			return nil, "Wins must be between 1 and 9 quadrillion"
		end
	elseif statName == "Speed" then
		amount = math.min(amount, tonumber(Config.MaxStoredSpeed) or 1e50)
	else
		return nil, "Unsupported stat"
	end

	return amount
end

local function queueSave(player)
	if not player or saveQueued[player] then
		return
	end
	saveQueued[player] = true
	table.insert(saveQueue, player)

	if saveWorkerRunning then
		return
	end
	saveWorkerRunning = true
	task.spawn(function()
		while #saveQueue > 0 do
			local target = table.remove(saveQueue, 1)
			saveQueued[target] = nil
			if target and target.Parent == Players and target:GetAttribute("DataLoaded") == true then
				local savePlayer = _G.SpeedsterSavePlayer
				if type(savePlayer) == "function" then
					savePlayer(target, "owner_admin_grant", false)
				end
			end
			                                                                     
			task.wait(0.15)
		end
		saveWorkerRunning = false
	end)
end

local function grantLoadedPlayer(player, statName, amount)
	local grantExact = _G.SpeedsterGrantExactStat
	if type(grantExact) ~= "function" then
		return false, "PlayerStats grant hook is not ready"
	end

	local ok, granted, result = pcall(grantExact, player, statName, amount)
	if not ok then
		warn("[OwnerAdminPanel] Exact grant failed for " .. player.Name .. ": " .. tostring(granted))
		return false, "Grant failed"
	end
	if granted ~= true then
		return false, tostring(result or "Grant rejected")
	end

	queueSave(player)
	return true, result
end

local function grantPlayerWhenReady(player, statName, amount)
	if player:GetAttribute("DataLoaded") == true then
		local ok = grantLoadedPlayer(player, statName, amount)
		return ok, false
	end

	task.spawn(function()
		local deadline = os.clock() + 30
		while player.Parent == Players
			and player:GetAttribute("DataLoaded") ~= true
			and os.clock() < deadline
		do
			task.wait(0.1)
		end
		if player.Parent == Players and player:GetAttribute("DataLoaded") == true then
			grantLoadedPlayer(player, statName, amount)
		end
	end)
	return false, true
end

local function applyGrantToThisServer(statName, amount)
	local applied = 0
	local queued = 0
	for _, target in ipairs(Players:GetPlayers()) do
		local ok, waiting = grantPlayerWhenReady(target, statName, amount)
		if ok then
			applied += 1
		elseif waiting then
			queued += 1
		end
	end
	return applied, queued
end

local function rememberMessage(messageId)
	if processedMessages[messageId] then
		return false
	end
	processedMessages[messageId] = true
	table.insert(processedMessageOrder, messageId)
	while #processedMessageOrder > 100 do
		local old = table.remove(processedMessageOrder, 1)
		processedMessages[old] = nil
	end
	return true
end

local readGlobalCommandRecord
local function handleGlobalMessage(message)
	local data = message and message.Data
	if type(data) ~= "table"
		or data.Version ~= "V306GY"
		or tonumber(data.OwnerUserId) ~= OWNER_USER_ID
		or type(data.MessageId) ~= "string"
		or type(data.OriginRunId) ~= "string"
		or math.abs(os.time() - (tonumber(data.IssuedAt) or 0)) > GLOBAL_MESSAGE_MAX_AGE
	then
		return
	end
	if data.OriginRunId == runId or not rememberMessage(data.MessageId) then
		return
	end

	                                                                      
	                                                                        
	                                                                   
	local record = readGlobalCommandRecord(data.MessageId)
	if type(record) ~= "table"
		or record.Version ~= "V306GY"
		or record.MessageId ~= data.MessageId
		or record.OriginRunId ~= data.OriginRunId
		or tonumber(record.OwnerUserId) ~= OWNER_USER_ID
		or record.Stat ~= data.Stat
		or tonumber(record.Amount) ~= tonumber(data.Amount)
		or tonumber(record.IssuedAt) ~= tonumber(data.IssuedAt)
	then
		warn("[OwnerAdminPanel] Rejected an unverified global grant message")
		return
	end

	local amount = parseAmount(data.Amount, data.Stat)
	if not amount then
		return
	end
	applyGrantToThisServer(data.Stat, amount)
end

local function commandStoreKey(messageId)
	return "Command_" .. tostring(messageId)
end

local function writeGlobalCommandRecord(payload)
	local ok, err = pcall(function()
		globalCommandStore:SetAsync(commandStoreKey(payload.MessageId), payload)
	end)
	if not ok then
		warn("[OwnerAdminPanel] Could not persist global command proof: " .. tostring(err))
	end
	return ok
end

readGlobalCommandRecord = function(messageId)
	local ok, data = pcall(function()
		return globalCommandStore:GetAsync(commandStoreKey(messageId))
	end)
	if not ok then
		warn("[OwnerAdminPanel] Could not verify global command proof: " .. tostring(data))
		return nil
	end
	return data
end

local subscriptionReady = false
local subscriptionConnection = nil
local function subscribeToGlobalGrants(attempt)
	if subscriptionReady then
		return
	end
	local ok, result = pcall(function()
		return MessagingService:SubscribeAsync(GLOBAL_TOPIC, handleGlobalMessage)
	end)
	if ok then
		subscriptionConnection = result
		subscriptionReady = true
		return
	end
	warn("[OwnerAdminPanel] Global grant subscription attempt " .. tostring(attempt) .. " failed: " .. tostring(result))
	if attempt < 3 then
		task.delay(attempt * 3, subscribeToGlobalGrants, attempt + 1)
	end
end
task.defer(subscribeToGlobalGrants, 1)

local function isTreadmillTemplate(object, exactName)
	return object
		and object.Parent
		and object.Name == exactName
		and (object:IsA("Model") or object:IsA("BasePart"))
		and not object:IsDescendantOf(spawnedFolder)
		and object:GetAttribute("StageDecorClone") ~= true
		and object:GetAttribute("OwnerAdminSpawned") ~= true
end

local function findTreadmillTemplate(exactName)
	local cached = treadmillTemplateCache[exactName]
	if isTreadmillTemplate(cached, exactName) then
		return cached
	end

	for _, object in ipairs(Workspace:GetDescendants()) do
		if isTreadmillTemplate(object, exactName) then
			treadmillTemplateCache[exactName] = object
			return object
		end
	end
	return nil
end

Workspace.DescendantAdded:Connect(function(object)
	if treadmillAllowed[object.Name] and isTreadmillTemplate(object, object.Name) then
		treadmillTemplateCache[object.Name] = treadmillTemplateCache[object.Name] or object
	end
end)

Workspace.DescendantRemoving:Connect(function(object)
	if treadmillTemplateCache[object.Name] == object then
		treadmillTemplateCache[object.Name] = nil
	end
end)

local function sanitizeSpawnedTreadmill(clone)
	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("LuaSourceContainer") then
			object:Destroy()
		elseif object:IsA("BasePart") then
			object.Anchored = true
			object.AssemblyLinearVelocity = Vector3.zero
			object.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.AssemblyLinearVelocity = Vector3.zero
		clone.AssemblyAngularVelocity = Vector3.zero
	end
end

local function spawnTreadmill(player, treadmillName)
	if not treadmillAllowed[treadmillName] then
		return false, "Unknown treadmill"
	end
	if os.clock() - (lastSpawnAt[player] or -math.huge) < SPAWN_COOLDOWN then
		return false, "Wait a moment before spawning another treadmill"
	end
	lastSpawnAt[player] = os.clock()

	if #spawnedFolder:GetChildren() >= MAX_ADMIN_SPAWNED_TREADMILLS then
		return false, "Safe limit reached: remove an owner-spawned treadmill first"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, "Your character is not ready"
	end

	local source = findTreadmillTemplate(treadmillName)
	if not source then
		return false, treadmillName .. " was not found in Workspace"
	end

	local cloneOk, clone = pcall(function()
		return source:Clone()
	end)
	if not cloneOk or not clone then
		return false, "Roblox could not clone " .. treadmillName
	end
	clone.Name = treadmillName
	clone:SetAttribute("OwnerAdminSpawned", true)
	clone:SetAttribute("OwnerAdminSpawnedBy", OWNER_USER_ID)
	clone:SetAttribute("OwnerAdminSpawnedAt", os.time())
	clone:SetAttribute("TreadmillTrainingSourceName", treadmillName)
	sanitizeSpawnedTreadmill(clone)
	clone.Parent = spawnedFolder

	local boxCFrame, boxSize
	local boxOk, boxError = pcall(function()
		if clone:IsA("Model") then
			boxCFrame, boxSize = clone:GetBoundingBox()
		else
			boxCFrame, boxSize = clone.CFrame, clone.Size
		end
	end)
	if not boxOk or not boxCFrame or not boxSize then
		clone:Destroy()
		return false, "The treadmill has no usable geometry: " .. tostring(boxError)
	end

	local feetY = root.Position.Y - humanoid.HipHeight - (root.Size.Y * 0.5)
	local targetCenter = Vector3.new(root.Position.X, feetY - (boxSize.Y * 0.5) + 0.05, root.Position.Z)
	local targetBoxCFrame = CFrame.new(targetCenter) * boxCFrame.Rotation
	local translation = targetBoxCFrame * boxCFrame:Inverse()
	if clone:IsA("Model") then
		clone:PivotTo(translation * clone:GetPivot())
	else
		clone.CFrame = targetBoxCFrame
	end

	return true, treadmillName .. " spawned under you"
end

local function publishGlobalGrant(statName, amount, messageId)
	local payload = {
		Version = "V306GY",
		MessageId = messageId,
		OwnerUserId = OWNER_USER_ID,
		OriginRunId = runId,
		IssuedAt = os.time(),
		Stat = statName,
		Amount = amount,
	}
	if not writeGlobalCommandRecord(payload) then
		return false
	end
	for attempt = 1, 2 do
		local ok, err = pcall(function()
			MessagingService:PublishAsync(GLOBAL_TOPIC, payload)
		end)
		if ok then
			return true
		end
		if attempt < 2 then
			task.wait(0.4)
		else
			warn("[OwnerAdminPanel] Global grant publish failed: " .. tostring(err))
		end
	end
	return false
end

adminRemote.OnServerEvent:Connect(function(player, request)
	if not isOwner(player) or type(request) ~= "table" then
		return
	end

	local action = tostring(request.Action or "")
	if not validActionRate(player, action) then
		return
	end

	if action == "GetState" then
		if panelOpenRequested[player] then
			panelOpenRequested[player] = nil
			openPanel(player)
		end
		send(player, {
			Type = "State",
			Flying = player:GetAttribute("AdminFlying") == true,
		})
	elseif action == "SetFly" then
		local enabled = request.Enabled == true
		player:SetAttribute("AdminFlying", enabled)
		send(player, { Type = "FlyState", Flying = enabled })
		sendResult(player, true, enabled and "Flight enabled" or "Flight disabled")
	elseif action == "SpawnTreadmill" then
		local ok, message = spawnTreadmill(player, tostring(request.Treadmill or ""))
		sendResult(player, ok, message)
	elseif action == "Grant" then
		local statName = request.Stat == "Wins" and "Wins" or (request.Stat == "Speed" and "Speed" or nil)
		local scope = request.Scope == "Global" and "Global" or (request.Scope == "Server" and "Server" or nil)
		if not statName or not scope then
			sendResult(player, false, "Invalid grant request")
			return
		end

		local amount, amountError = parseAmount(request.Amount, statName)
		if not amount then
			sendResult(player, false, amountError)
			return
		end

		if scope == "Server" then
			local applied, queued = applyGrantToThisServer(statName, amount)
			sendResult(player, true, string.format(
				"%s granted to this server: %d applied, %d loading",
				statName,
				applied,
				queued
			))
			return
		end

		local messageId = HttpService:GenerateGUID(false)
		local published = publishGlobalGrant(statName, amount, messageId)
		if published then
			local applied, queued = applyGrantToThisServer(statName, amount)
			sendResult(player, true, string.format(
				"%s sent to every live server: %d applied here, %d loading",
				statName,
				applied,
				queued
			))
		else
			sendResult(player, false, "Global grant failed before anyone was changed")
		end
	end
end)

local function queueOpenPanel(player)
	if not isOwner(player) then
		return
	end
	panelOpenRequested[player] = true
	openPanel(player)
end

local function bindOwnerChat(player)
	if not isOwner(player) then
		return
	end
	player.Chatted:Connect(function(message)
		local normalized = tostring(message or ""):lower():match("^%s*(.-)%s*$")
		if normalized == "?panel" or normalized == "/panel" then
			queueOpenPanel(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	initializeOwnerState(player)
	bindOwnerChat(player)
end
Players.PlayerAdded:Connect(function(player)
	initializeOwnerState(player)
	bindOwnerChat(player)
end)

                                                                           
                                                                      
local panelCommand = TextChatService:FindFirstChild("SpeedsterOwnerPanelCommand")
if panelCommand and not panelCommand:IsA("TextChatCommand") then
	panelCommand:Destroy()
	panelCommand = nil
end
if not panelCommand then
	panelCommand = Instance.new("TextChatCommand")
	panelCommand.Name = "SpeedsterOwnerPanelCommand"
	panelCommand.PrimaryAlias = "panel"
	panelCommand.SecondaryAlias = "ownerpanel"
	panelCommand.AutocompleteVisible = false
	panelCommand.Parent = TextChatService
end

panelCommand.Triggered:Connect(function(originTextSource)
	local player = originTextSource and Players:GetPlayerByUserId(originTextSource.UserId)
	queueOpenPanel(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
	panelOpenRequested[player] = nil
	lastSpawnAt[player] = nil
	saveQueued[player] = nil
end)

print("[OwnerAdminPanel] V306GY loaded | owner=5113549114 | /panel + ?panel | exact grants | global-online MessagingService | five treadmill spawns | validated flight")
