local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local CodesStore = DataStoreService:GetDataStore("AdminAbuseCodes_v1")
local AdminGlobalEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AdminGlobalEvents"))
local MessagingService = game:GetService("MessagingService")

local AdminRemote = Instance.new("RemoteEvent")
AdminRemote.Name = "AdminAbuseRemote"
AdminRemote.Parent = RemotesFolder

local DISCO_CONNECTIONS = {}
local STROBE_CONNECTION = nil
local DISCO_BALLS = {}
local DISCO_COLOR_CORRECTION = nil
local DISCO_ENABLED = false
local STROBE_ENABLED = false
local FOG_ENABLED = false
local DEFAULT_BRIGHTNESS = Lighting.Brightness
local DEFAULT_CLOCK_TIME = Lighting.ClockTime
local DEFAULT_AMBIENT = Lighting.Ambient
local DEFAULT_OUTDOOR_AMBIENT = Lighting.OutdoorAmbient
local DEFAULT_FOG_START = Lighting.FogStart
local DEFAULT_FOG_END = Lighting.FogEnd
local DEFAULT_FOG_COLOR = Lighting.FogColor
local DEFAULT_GLOBAL_SHADOWS = Lighting.GlobalShadows
local DISCO_SPEC = nil
local ADMIN_SPAWNED_FOLDER = "AdminSpawnedTreadmills"
local ADMIN_TREADMILL_GAIN_KEY = "Treadmill5_insanespeed"
local ADMIN_TREADMILL_RAISE = 3
local ADMIN_TREADMILL_OFFSET = 15

local function getTreadmillDefaults()
	local cfg = AdminGlobalEvents.DEFAULT_TREADMILL or {}
	return {
		SpeedMult = math.clamp(tonumber(cfg.SpeedMult) or 5, 1, 100),
		WinMult = math.clamp(tonumber(cfg.WinMult) or 2, 1, 100),
		WinBase = math.max(1, tonumber(cfg.WinBase) or 200),
	}
end

local function applyTreadmillMultiplierGlobals(speedMult, winMult)
	local def = getTreadmillDefaults()
	_G.AdminTreadmillSpeedMult = math.clamp(tonumber(speedMult) or def.SpeedMult, 1, 100)
	_G.AdminTreadmillWinMult = math.clamp(tonumber(winMult) or def.WinMult, 1, 100)
end

local function isPlayerAdmin(player)
	return AdminBannerConfig.IsAdmin(player.UserId)
end

local function getAdminDisplayName(player)
	local cfg = AdminBannerConfig.GetConfig(player.UserId)
	return cfg and cfg.DisplayName or player.Name
end

local function broadcastToAllClients(payload)
	AdminRemote:FireAllClients(payload)
end

local function sendToAdmin(player, payload)
	if isPlayerAdmin(player) then
		AdminRemote:FireClient(player, payload)
	end
end

local function cloneGuiToPlayer(player)
	if not isPlayerAdmin(player) then
		return
	end
	local guiTemplate = ServerStorage:FindFirstChild("AdminAbusePanelGui")
	if not guiTemplate then
		return
	end
	local existing = player.PlayerGui:FindFirstChild("AdminAbusePanelGui")
	if existing then
		existing:Destroy()
	end
	local clone = guiTemplate:Clone()
	clone.Parent = player.PlayerGui
end

local function formatAdminText(adminName, hasBadge, colorValue, message)
	local colorStr
	if colorValue == "RAINBOW" then
		colorStr = "255,255,255"
	elseif typeof(colorValue) == "Color3" then
		colorStr = math.floor(colorValue.R * 255) .. "," .. math.floor(colorValue.G * 255) .. "," .. math.floor(colorValue.B * 255)
	else
		colorStr = "255,255,255"
	end
	local badge = hasBadge and '<font color="rgb(40,220,140)"><b> \</b></font>' or ""
	return '<font color="rgb(' .. colorStr .. ')">' .. adminName .. '</font>' .. badge .. ': ' .. message
end

local function parseColor(raw)
	if not raw or raw == "" then
		return nil
	end
	local cleaned = raw:lower():gsub("%s", "")
	if cleaned == "rainbow" then
		return "RAINBOW"
	end
	local r, g, b = cleaned:match("(%d+),(%d+),(%d+)")
	if r and g and b then
		return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
	end
	return nil
end

local function resetDiscoVisuals()
	for _, conn in ipairs(DISCO_CONNECTIONS) do
		if conn.Connected then conn:Disconnect() end
	end
	DISCO_CONNECTIONS = {}
	for _, ball in ipairs(DISCO_BALLS) do
		if ball and ball.Parent then ball:Destroy() end
	end
	DISCO_BALLS = {}
	if DISCO_COLOR_CORRECTION and DISCO_COLOR_CORRECTION.Parent then
		DISCO_COLOR_CORRECTION:Destroy()
	end
	DISCO_COLOR_CORRECTION = nil
	Lighting.Ambient = DEFAULT_AMBIENT
	Lighting.OutdoorAmbient = DEFAULT_OUTDOOR_AMBIENT
	Lighting.Brightness = DEFAULT_BRIGHTNESS
	Lighting.ClockTime = DEFAULT_CLOCK_TIME
	Lighting.GlobalShadows = DEFAULT_GLOBAL_SHADOWS
end

local function findTreadmillCenters()
	local centers = {}
	local treadmillArea = workspace:FindFirstChild("neworld1") and workspace.neworld1:FindFirstChild("Treadmillarea")
	if treadmillArea then
		local parts = {}
		for _, child in ipairs(treadmillArea:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		if #parts > 0 then
			local sum = Vector3.new()
			for _, p in ipairs(parts) do sum += p.Position end
			table.insert(centers, sum / #parts)
		end
	end
	local loc = workspace:FindFirstChild("SpawnLocation")
	if loc and loc:IsA("BasePart") then
		table.insert(centers, loc.Position + Vector3.new(0, 18, 0))
	end
	if #centers == 0 then
		table.insert(centers, Vector3.new(0, 60, 0))
	end
	return centers
end

local function spawnDiscoBalls(ballCount)
	local template = ReplicatedStorage:FindFirstChild("DiscoBall")
	if not template then return end
	local folder = workspace:FindFirstChild(AdminGlobalEvents.DiscoBallFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = AdminGlobalEvents.DiscoBallFolderName
		folder.Parent = workspace
	end
	local centers = findTreadmillCenters()
	local count = math.min(tonumber(ballCount) or 1, #centers)
	for i = 1, count do
		local center = centers[i]
		local ok, ball = pcall(function() return template:Clone() end)
		if ok and ball then
			ball.Name = "DiscoBall"
			ball.Parent = folder
			ball:PivotTo(CFrame.new(center.X, center.Y + 22, center.Z))
			local ballConn = nil
			local spinStart = os.clock()
			ballConn = RunService.Heartbeat:Connect(function()
				if not ball.Parent then
					if ballConn then ballConn:Disconnect() end
					return
				end
				local t = os.clock() - spinStart
				ball:PivotTo(CFrame.new(center.X, center.Y + 22 + math.sin(t * 0.8) * 2.5, center.Z) * CFrame.Angles(0, t * 1.2, 0))
			end)
			table.insert(DISCO_CONNECTIONS, ballConn)
			table.insert(DISCO_BALLS, ball)
		end
	end
end

local function startDisco(spec)
	spec = spec or {}
	local cfg = AdminGlobalEvents.DEFAULT_DISCO
	local brightness = math.clamp(tonumber(spec.Brightness) or cfg.Brightness, 0, 1)
	local saturation = math.clamp(tonumber(spec.Saturation) or cfg.Saturation, 0, 1)
	local ballCount = math.clamp(tonumber(spec.BallCount) or cfg.BallCount, 1, 6)
	DISCO_SPEC = spec
	if DISCO_ENABLED then
		resetDiscoVisuals()
	end
	DISCO_ENABLED = true
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.Ambient
	Lighting.GlobalShadows = true

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "AdminDiscoColorCorrection"
	colorCorrection.Brightness = -0.05
	colorCorrection.Contrast = cfg.Contrast
	colorCorrection.Saturation = saturation
	colorCorrection.TintColor = Color3.fromRGB(255, 128, 160)
	colorCorrection.Parent = Lighting
	DISCO_COLOR_CORRECTION = colorCorrection

	spawnDiscoBalls(ballCount)

	local timeVal = 0
	table.insert(DISCO_CONNECTIONS, RunService.Heartbeat:Connect(function(dt)
		if not DISCO_ENABLED then return end
		timeVal = timeVal + dt * 1
		local hue = (timeVal / 8) % 1
		if DISCO_COLOR_CORRECTION and DISCO_COLOR_CORRECTION.Parent then
			DISCO_COLOR_CORRECTION.TintColor = Color3.fromHSV(hue, 0.35, 1)
		end
		for _, ball in ipairs(DISCO_BALLS) do
			if ball and ball.Parent then
				local light = ball:FindFirstChild("PointLight", true)
				if light then
					light.Color = Color3.fromHSV(hue, 0.45, 1)
					light.Brightness = 1
				end
			end
		end
	end))
end

local function stopDisco()
	local wasEnabled = DISCO_ENABLED
	resetDiscoVisuals()
	DISCO_ENABLED = false
	return wasEnabled
end

local function stopStrobe()
	if STROBE_CONNECTION and STROBE_CONNECTION.Connected then
		STROBE_CONNECTION:Disconnect()
	end
	STROBE_CONNECTION = nil
	STROBE_ENABLED = false
	Lighting.Brightness = DEFAULT_BRIGHTNESS
end

local function startStrobe()
	if STROBE_ENABLED then
		stopStrobe()
		return
	end
	STROBE_ENABLED = true
	local on = false
	STROBE_CONNECTION = RunService.Heartbeat:Connect(function()
		on = not on
		Lighting.Brightness = on and (DEFAULT_BRIGHTNESS + 0.4) or DEFAULT_BRIGHTNESS
	end)
end

local function toggleFog()
	FOG_ENABLED = not FOG_ENABLED
	if FOG_ENABLED then
		Lighting.FogStart = 0
		Lighting.FogEnd = 80
		Lighting.FogColor = Color3.fromRGB(40, 0, 0)
	else
		Lighting.FogStart = DEFAULT_FOG_START
		Lighting.FogEnd = DEFAULT_FOG_END
		Lighting.FogColor = DEFAULT_FOG_COLOR
	end
end

local function resetAllNormal()
	stopDisco()
	stopStrobe()
	FOG_ENABLED = false
	Lighting.FogStart = DEFAULT_FOG_START
	Lighting.FogEnd = DEFAULT_FOG_END
	Lighting.FogColor = DEFAULT_FOG_COLOR
	Lighting.Brightness = DEFAULT_BRIGHTNESS
	Lighting.ClockTime = DEFAULT_CLOCK_TIME
	Lighting.Ambient = DEFAULT_AMBIENT
	Lighting.OutdoorAmbient = DEFAULT_OUTDOOR_AMBIENT
	Lighting.GlobalShadows = DEFAULT_GLOBAL_SHADOWS
	-- Also remove any admin-spawned treadmills so the server returns to normal.
	local adminFolder = workspace:FindFirstChild(ADMIN_SPAWNED_FOLDER)
	if adminFolder then
		for _, clone in ipairs(adminFolder:GetChildren()) do
			clone:Destroy()
		end
		adminFolder:Destroy()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.UseJumpPower = false
			humanoid.JumpHeight = 7.2
		end
	end
end

local function broadcastEffectsStatus()
	broadcastToAllClients({
		Type = "EffectsStatus",
		Disco = DISCO_ENABLED,
		Strobe = STROBE_ENABLED,
		Fog = FOG_ENABLED,
	})
end

local CONFETTI_COUNT = 15
local CONFETTI_LIFETIME = 5
local confettiCounter = 0
local activeConfetti = {}

local function grantConfettiBoost(player, speedMult, winMult, durationMin)
	speedMult = math.clamp(tonumber(speedMult) or 2, 1, 50)
	winMult = math.clamp(tonumber(winMult) or 2, 1, 50)
	durationMin = math.clamp(tonumber(durationMin) or 5, 0.5, 120)
	local curExp = tonumber(player:GetAttribute("ConfettiBoostExpire")) or 0
	player:SetAttribute("ConfettiBoostExpire", math.max(curExp, os.time()) + durationMin * 60)
	player:SetAttribute("ConfettiSpeedMult", speedMult)
	player:SetAttribute("ConfettiWinMult", winMult)
	AdminRemote:FireClient(player, {
		Type = "ConfettiCollected",
		SpeedMult = speedMult,
		WinMult = winMult,
		Minutes = durationMin,
	})
end

local function fireConfetti(player, lifetimeSeconds, count, speedMult, winMult, boostDuration)
	local lifetime = math.clamp(tonumber(lifetimeSeconds) or CONFETTI_LIFETIME, 1, 120)
	local spawnCount = math.clamp(tonumber(count) or CONFETTI_COUNT, 1, 120)
	speedMult = math.clamp(tonumber(speedMult) or 2, 1, 50)
	winMult = math.clamp(tonumber(winMult) or 2, 1, 50)
	boostDuration = math.clamp(tonumber(boostDuration) or 5, 0.5, 120)

	local cfg = AdminGlobalEvents.DEFAULT_CONFETTI
	local fallHeight = tonumber(cfg.FallHeight) or 140
	local fallRange = tonumber(cfg.FallRange) or 90
	local center
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		center = root.Position
	else
		local loc = workspace:FindFirstChild("SpawnLocation")
		center = loc and loc:IsA("BasePart") and loc.Position or Vector3.new(0, 40, 0)
	end

	for i = 1, spawnCount do
		confettiCounter = confettiCounter + 1
		local id = confettiCounter
		local angle = (i / spawnCount) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local dist = math.random() * fallRange
		local x = center.X + math.cos(angle) * dist
		local z = center.Z + math.sin(angle) * dist
		local spawnY = center.Y + fallHeight
		local part = Instance.new("Part")
		part.Name = "AdminConfetti"
		part.Size = Vector3.new(1.4, 1.4, 0.25)
		part.Anchored = false
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromHSV(math.random(), 1, 1)
		part.CastShadow = false
		part.CFrame = CFrame.new(x, spawnY, z)
		part.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 20, -10 - math.random() * 12, (math.random() - 0.5) * 20)
		part.Parent = workspace

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CollectConfetti"
		prompt.ActionText = "Collect"
		local multLabel = {}
		if speedMult > 1 then table.insert(multLabel, tostring(speedMult) .. "x Speed") end
		if winMult > 1 then table.insert(multLabel, tostring(winMult) .. "x Wins") end
		if #multLabel == 0 then table.insert(multLabel, "Boost") end
		prompt.ObjectText = table.concat(multLabel, " & ")
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = part

		activeConfetti[id] = { Part = part, Claimed = false }

		local startHue = math.random()
		local bobConn = nil
		local bobStart = os.clock()
		bobConn = RunService.Heartbeat:Connect(function()
			if not part.Parent then
				if bobConn then bobConn:Disconnect() end
				return
			end
			local t = os.clock() - bobStart
			local hue = (startHue + t * 0.15) % 1
			part.Color = Color3.fromHSV(hue, 1, 1)
			part.CFrame = part.CFrame * CFrame.Angles(0, 0.25, 0)
		end)

		prompt.Triggered:Connect(function(triggerPlayer)
			if activeConfetti[id] and not activeConfetti[id].Claimed then
				activeConfetti[id].Claimed = true
				grantConfettiBoost(triggerPlayer, speedMult, winMult, boostDuration)
				if part.Parent then part:Destroy() end
				activeConfetti[id] = nil
			end
		end)

		part.AncestryChanged:Connect(function()
			if not part.Parent then
				if bobConn then bobConn:Disconnect() end
				activeConfetti[id] = nil
			end
		end)

		task.delay(lifetime, function()
			if part.Parent then part:Destroy() end
			activeConfetti[id] = nil
		end)
	end
end

local function applyMultipliers(speedVal, jumpVal, winMulti)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if speedVal then
				humanoid.WalkSpeed = math.clamp(tonumber(speedVal) or 16, 0, 500)
			end
			if jumpVal then
				humanoid.UseJumpPower = false
				humanoid.JumpHeight = math.clamp(tonumber(jumpVal) or 7.2, 0, 200)
			end
		end
	end
end

local function despawnAdminTreadmills()
	-- Hardened: destroy every admin treadmill no matter where it ended up.
	-- Primary path: the dedicated folder (destroy the folder itself too).
	-- Fallback: scan the whole workspace for any object tagged AdminSpawned
	-- (e.g. if a move/parenting hiccup left one outside the folder).
	local removed = 0
	local folder = workspace:FindFirstChild(ADMIN_SPAWNED_FOLDER)
	if folder then
		for _, obj in ipairs(folder:GetChildren()) do
			obj:Destroy()
			removed = removed + 1
		end
		folder:Destroy()
	end
	local strays = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:GetAttribute("AdminSpawned") == true and obj.Parent then
			table.insert(strays, obj)
		end
	end
	for _, obj in ipairs(strays) do
		obj:Destroy()
		removed = removed + 1
	end
	return removed
end

local function spawnAdminTreadmill(player, durationSeconds)
	local neworld1 = workspace:FindFirstChild("neworld1")
	local spawnLocation = neworld1 and neworld1:FindFirstChild("SpawnLocation")
	if not spawnLocation or not spawnLocation:IsA("BasePart") then
		return false, "Spawn location not found"
	end

	-- Spawn the special "Admin" treadmill (moved to ReplicatedStorage) instead
	-- of the normal "Basic" treadmill players use, so admin spawns stand out.
	local template = ReplicatedStorage:FindFirstChild("Admin") or neworld1:FindFirstChild("Basic")
	if not template or not template:IsA("Model") then
		return false, "Treadmill template not found"
	end

	local treadmillFolder = workspace:FindFirstChild(ADMIN_SPAWNED_FOLDER)
	if not treadmillFolder then
		treadmillFolder = Instance.new("Folder")
		treadmillFolder.Name = ADMIN_SPAWNED_FOLDER
		treadmillFolder.Parent = workspace
	end

	local cloneOk, clone = pcall(function()
		return template:Clone()
	end)
	if not cloneOk or not clone then
		return false, "Could not clone treadmill"
	end

	clone.Name = "AdminTreadmill"
	clone:SetAttribute("AdminSpawned", true)
	clone:SetAttribute("AdminSpawnedBy", player.UserId)
	clone:SetAttribute("AdminSpawnedAt", os.time())
	clone:SetAttribute("TreadmillTrainingSourceName", ADMIN_TREADMILL_GAIN_KEY)

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
	end

	clone.Parent = treadmillFolder

	local boxCFrame, boxSize
	local boxOk, boxError = pcall(function()
		boxCFrame, boxSize = clone:GetBoundingBox()
	end)
	if not boxOk or not boxCFrame or not boxSize then
		clone:Destroy()
		return false, "Treadmill has no usable geometry"
	end

	local offsetX = tonumber(ADMIN_TREADMILL_OFFSET) or 15
	local raiseAbove = tonumber(ADMIN_TREADMILL_RAISE) or 3
	local spawnTop = spawnLocation.Position.Y + spawnLocation.Size.Y * 0.5
	local targetY = spawnTop + raiseAbove + (boxSize.Y * 0.5)
	local pivot = CFrame.new(spawnLocation.Position.X - offsetX, targetY, spawnLocation.Position.Z) * boxCFrame.Rotation
	clone:PivotTo(pivot * CFrame.Angles(0, -math.rad(90), 0))

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = clone

	local hueStart = os.clock()
	local hConn = nil
	hConn = RunService.Heartbeat:Connect(function()
		if not clone.Parent then
			if hConn then hConn:Disconnect() end
			return
		end
		local hue = (os.clock() - hueStart) * 0.5 % 1
		local rainbowColor = Color3.fromHSV(hue, 1, 1)
		highlight.OutlineColor = rainbowColor
		highlight.FillColor = rainbowColor
	end)

	if durationSeconds and durationSeconds > 0 then
		local conn = nil
		conn = clone.AncestryChanged:Connect(function()
			if conn then conn:Disconnect() end
		end)
		task.delay(durationSeconds, function()
			if clone.Parent then
				clone:Destroy()
			end
			if conn then conn:Disconnect() end
		end)
	end

	local suffix = ""
	if durationSeconds and durationSeconds > 0 then
		suffix = " for " .. tostring(math.floor(durationSeconds)) .. "s"
	end
	return true, "Admin treadmill spawned at center of spawn" .. suffix
end

local function createCode(codeName, statName, statAmount)
	if not codeName or codeName == "" then return false, "Code name is required" end
	if not statName or statName == "" then return false, "Stat name is required" end
	local amount = tonumber(statAmount)
	if not amount or amount <= 0 then return false, "Invalid stat amount" end
	local key = "code_" .. codeName:lower():gsub("%s", "_")
	local ok, err = pcall(function()
		CodesStore:SetAsync(key, {
			CodeName = codeName,
			StatName = statName,
			StatAmount = amount,
			CreatedBy = "Admin",
			CreatedAt = os.time(),
			RedeemedBy = {},
		})
	end)
	if ok then
		return true, "Code '" .. codeName .. "' created"
	else
		return false, "DataStore error: " .. tostring(err)
	end
end

local function wipePlayerData(targetName)
	if not targetName or targetName == "" then return false, "Enter a username or UserId" end
	local userId = tonumber(targetName)
	if not userId then
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(targetName) end)
		if ok and id then
			userId = id
		else
			return false, "Could not find player: " .. targetName
		end
	end
	pcall(function() CodesStore:RemoveAsync("PlayerData_" .. userId) end)
	pcall(function() CodesStore:RemoveAsync("Stats_" .. userId) end)
	pcall(function() CodesStore:RemoveAsync("Data_" .. userId) end)
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if targetPlayer then
		targetPlayer:Kick("Your data has been wiped by an admin.")
	end
	return true, "Data wiped for UserId: " .. tostring(userId)
end

local SESSION_LOGS = {}
local CHAT_LOGS = {}
local MAX_LOG_ENTRIES = 200

local function addSessionLog(adminName, action, details)
	local entry = { Admin = adminName, Action = action, Details = details or "", Time = os.time() }
	table.insert(SESSION_LOGS, entry)
	if #SESSION_LOGS > MAX_LOG_ENTRIES then table.remove(SESSION_LOGS, 1) end
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAdmin(player) then
			AdminRemote:FireClient(player, { Type = "SessionLog", Entry = entry })
		end
	end
end

local function addChatLog(playerName, message, channel)
	local entry = { Player = playerName, Message = message, Channel = channel or "All", Time = os.time() }
	table.insert(CHAT_LOGS, entry)
	if #CHAT_LOGS > MAX_LOG_ENTRIES then table.remove(CHAT_LOGS, 1) end
	for _, player in ipairs(Players:GetPlayers()) do
		if isPlayerAdmin(player) then
			AdminRemote:FireClient(player, { Type = "ChatLog", Entry = entry })
		end
	end
end

local function onSendingMessage(message)
	if not message then return end
	local textSource = typeof(message) == "table" and message.TextSource or message.TextSource
	if not textSource then return end
	local userId = pcall(function() return textSource.UserId end) and textSource.UserId
	if not userId then return end
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	local channelName = "All"
	pcall(function()
		local ch = message.TextChannel
		if ch then channelName = ch.Name end
	end)
	addChatLog(player.Name, tostring(message.Text or ""), channelName)
end

if TextChatService.SendingMessage then
	TextChatService.SendingMessage:Connect(onSendingMessage)
end

-- ============================= GLOBAL EVENTS =============================
-- Cross-server events via MessagingService. Publishing is local-only in Studio
-- (pcall) so servers aren't affected by inherited-spectrum quirks. Each place
-- subscribes on the same topic; when a message arrives, it runs its own LOCAL
-- copy of the event, so both World 1 and World 2 react without any republish.
local function publishGlobal(action, data)
	pcall(function()
		MessagingService:PublishAsync(AdminGlobalEvents.TopicName, { Action = action, Data = data or {}, Sender = os.time() })
	end)
end

local function runLocalEvent(action, data)
	if action == "DiscoStart" then
		startDisco(data and data.Spec or nil)
		broadcastEffectsStatus()
	elseif action == "DiscoStop" then
		stopDisco()
		broadcastEffectsStatus()
	elseif action == "Confetti" then
		fireConfetti(nil, data and data.Duration, data and data.Count, data and data.SpeedMult, data and data.WinMult, data and data.BoostDuration)
		broadcastToAllClients({ Type = "ConfettiEffect" })
	elseif action == "ResetAll" then
		resetAllNormal()
		broadcastEffectsStatus()
		broadcastToAllClients({ Type = "ResetAllNormal" })
	end
end

local function setupGlobalSubscription()
	pcall(function()
		pcall(MessagingService.SubscribeAsync, MessagingService, AdminGlobalEvents.TopicName, function(message)
			local payload = message and message.Data
			if type(payload) ~= "table" then return end
			runLocalEvent(payload.Action, payload.Data)
		end)
	end)
end
setupGlobalSubscription()

local function handleAdminAction(player, request)
	if not isPlayerAdmin(player) then return end
	if type(request) ~= "table" then return end
	local action = tostring(request.Action or "")
	local adminName = getAdminDisplayName(player)

	if action == "Broadcast" then
		local message = tostring(request.Message or "")
		if message == "" then
			sendToAdmin(player, { Type = "ActionResult", Ok = false, Message = "Message cannot be empty" })
			return
		end
		local duration = tonumber(request.Duration) or 8
		local colorValue = parseColor(request.Color or "")
		local cfg = AdminBannerConfig.GetConfig(player.UserId)
		if colorValue == "RAINBOW" and (not cfg or not cfg.RainbowUnlocked) then
			sendToAdmin(player, { Type = "ActionResult", Ok = false, Message = "Rainbow not unlocked for your account" })
			return
		end
		if colorValue == nil then
			colorValue = cfg and cfg.DefaultColor or Color3.new(1, 1, 1)
		end
		local hasBadge = cfg and cfg.HasBadge or false
		broadcastToAllClients({
			Type = "Broadcast",
			FormattedText = formatAdminText(adminName, hasBadge, colorValue, message),
			Duration = duration,
			ColorMode = colorValue == "RAINBOW" and "RAINBOW" or "STATIC",
			ColorValue = colorValue,
			Typewriter = request.Typewriter == true,
			UseSound = request.UseSound == true,
			AdminName = adminName,
			HasBadge = hasBadge,
		})
		addSessionLog(adminName, "Broadcast", message)

	elseif action == "PlayMusic" then
		local songName = tostring(request.SongName or "")
		if songName == "" then
			sendToAdmin(player, { Type = "ActionResult", Ok = false, Message = "No song selected" })
			return
		end
		local musicFolder = ReplicatedStorage:FindFirstChild("Music")
		local soundObj = musicFolder and musicFolder:FindFirstChild(songName)
		if not soundObj or not soundObj:IsA("Sound") then
			sendToAdmin(player, { Type = "ActionResult", Ok = false, Message = "Sound not found: " .. songName })
			return
		end
		broadcastToAllClients({ Type = "PlayMusic", SoundId = soundObj.SoundId, SongName = songName, BPM = tonumber(request.BPM) or 128 })
		addSessionLog(adminName, "PlayMusic", songName)

	elseif action == "StopMusic" then
		broadcastToAllClients({ Type = "StopMusic" })
		addSessionLog(adminName, "StopMusic", "")

	elseif action == "ResumeMusic" then
		broadcastToAllClients({ Type = "ResumeMusic" })
		addSessionLog(adminName, "ResumeMusic", "")

	elseif action == "CreateCode" then
		local ok, msg = createCode(request.CodeName, request.StatName, request.StatAmount)
		sendToAdmin(player, { Type = "ActionResult", Ok = ok, Message = msg })
		if ok then addSessionLog(adminName, "CreateCode", request.CodeName) end

	elseif action == "ApplyMultipliers" then
		local speedVal = tonumber(request.SpeedValue)
		local jumpVal = tonumber(request.JumpValue)
		applyMultipliers(speedVal, jumpVal, nil)
		broadcastToAllClients({ Type = "ActionResult", Ok = true, Message = "Multipliers applied" })
		addSessionLog(adminName, "ApplyMultipliers", "Speed=" .. tostring(speedVal) .. " Jump=" .. tostring(jumpVal))

	elseif action == "SpawnTreadmill" then
		local duration = tonumber(request.Duration)
		applyTreadmillMultiplierGlobals(tonumber(request.SpeedMult), tonumber(request.WinMult))
		local ok, msg = spawnAdminTreadmill(player, duration)
		sendToAdmin(player, { Type = "ActionResult", Ok = ok, Message = msg or "Treadmill spawned" })
		addSessionLog(adminName, "SpawnTreadmill", (ok and msg or "") .. " SpeedMult=" .. tostring(_G.AdminTreadmillSpeedMult) .. " WinMult=" .. tostring(_G.AdminTreadmillWinMult))

	elseif action == "DespawnTreadmill" then
		local removed = despawnAdminTreadmills()
		applyTreadmillMultiplierGlobals()
		sendToAdmin(player, { Type = "ActionResult", Ok = true, Message = "Despawned " .. tostring(removed) .. " admin treadmill(s)" })
		addSessionLog(adminName, "DespawnTreadmill", tostring(removed))

	elseif action == "ResetAllNormal" then
		resetAllNormal()
		broadcastEffectsStatus()
		broadcastToAllClients({ Type = "ResetAllNormal" })
		addSessionLog(adminName, "ResetAllNormal", "")

	elseif action == "ToggleDisco" then
		local global = request.Global == true
		local discoSpec = request.DiscoSpec
		if global then
			if DISCO_ENABLED then
				publishGlobal("DiscoStop")
				stopDisco()
			else
				publishGlobal("DiscoStart", { Spec = discoSpec or nil })
				startDisco(discoSpec)
			end
			broadcastEffectsStatus()
			addSessionLog(adminName, "ToggleDisco(Global)", tostring(DISCO_ENABLED))
		else
			startDisco()
			broadcastEffectsStatus()
			addSessionLog(adminName, "ToggleDisco", tostring(DISCO_ENABLED))
		end

	elseif action == "ToggleStrobe" then
		startStrobe()
		broadcastEffectsStatus()
		addSessionLog(adminName, "ToggleStrobe", tostring(STROBE_ENABLED))

	elseif action == "ToggleFog" then
		toggleFog()
		broadcastEffectsStatus()
		addSessionLog(adminName, "ToggleFog", tostring(FOG_ENABLED))

	elseif action == "ConfettiEffect" then
		local global = request.Global == true
		local duration = tonumber(request.Duration)
		local count = tonumber(request.Count)
		local speedMult = tonumber(request.SpeedMult)
		local winMult = tonumber(request.WinMult)
		local boostDuration = tonumber(request.BoostDuration)
		fireConfetti(player, duration, count, speedMult, winMult, boostDuration)
		if global then
			publishGlobal("Confetti", { Duration = duration, Count = count, SpeedMult = speedMult, WinMult = winMult, BoostDuration = boostDuration })
		end
		broadcastToAllClients({ Type = "ConfettiEffect" })
		addSessionLog(adminName, "ConfettiEffect", "Count=" .. tostring(count or 15) .. " SpeedMult=" .. tostring(speedMult or 2) .. " WinMult=" .. tostring(winMult or 2) .. (global and " GLOBAL" or ""))

	elseif action == "CameraShake" then
		local intensity = math.clamp(tonumber(request.Intensity) or 1, 0.1, 5)
		local dur = math.clamp(tonumber(request.Duration) or 1, 0.1, 10)
		broadcastToAllClients({ Type = "CameraShake", Intensity = intensity, Duration = dur })
		addSessionLog(adminName, "CameraShake", "Intensity=" .. tostring(intensity))

	elseif action == "ClaimConfetti" then
		pcall(function() end)

	elseif action == "WipeData" then
		local ok, msg = wipePlayerData(tostring(request.Target or ""))
		sendToAdmin(player, { Type = "ActionResult", Ok = ok, Message = msg })
		if ok then addSessionLog(adminName, "WipeData", tostring(request.Target)) end

	elseif action == "GetSessionLogs" then
		for _, entry in ipairs(SESSION_LOGS) do
			sendToAdmin(player, { Type = "SessionLog", Entry = entry })
		end

	elseif action == "GetChatLogs" then
		for _, entry in ipairs(CHAT_LOGS) do
			sendToAdmin(player, { Type = "ChatLog", Entry = entry })
		end

	elseif action == "GetMusicList" then
		local musicFolder = ReplicatedStorage:FindFirstChild("Music")
		local songs = {}
		if musicFolder then
			for _, child in ipairs(musicFolder:GetChildren()) do
				if child:IsA("Sound") then
					table.insert(songs, child.Name)
				end
			end
		end
		sendToAdmin(player, { Type = "MusicList", Songs = songs })

	elseif action == "GetEffectsStatus" then
		sendToAdmin(player, {
			Type = "EffectsStatus",
			Disco = DISCO_ENABLED,
			Strobe = STROBE_ENABLED,
			Fog = FOG_ENABLED,
		})
	end
end

AdminRemote.OnServerEvent:Connect(handleAdminAction)

Players.PlayerAdded:Connect(function(player)
	cloneGuiToPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(cloneGuiToPlayer, player)
end