--!strict
if true then
	return -- Admin Panel Service disabled for clean Update 3 patch
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
local CodesCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CodesCatalog"))

local Validation = require(ServerScriptService.Admin.AdminRequestValidation)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)
local acceptCodeEvent = Validation.NewEventCache()

local WORLD_2_PLACE_ID = 116359653478954
local MESSAGING_TOPIC = "SpeedsterGlobalAnnouncements_v1"
local CODES_MESSAGING_TOPIC = "SpeedsterGlobalCodes_v1"

local ALLOWED_USER_IDS: { [number]: boolean } = {
	[767108248] = true,
	[5113549114] = true,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage
local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if remote then remote:Destroy() end
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local AdminPanelAction = ensureRemote("AdminPanelAction")
local AdminPanelStatus = ensureRemote("AdminPanelStatus")
local DisplayRemote = ensureRemote("DisplayGlobalAnnouncement")

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ALLOWED_USER_IDS[player.UserId] == true then return true end
	if AdminBannerConfig.IsAdmin(player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local function sendToast(player: Player, success: boolean, message: string)
	if player and player.Parent == Players then
		AdminPanelStatus:FireClient(player, {
			kind = "Toast",
			success = success,
			message = message,
		})
	end
end

local function resolveTargets(admin: Player, rawTarget: any): { Player }
	if rawTarget == "All" or rawTarget == "all" then
		return Players:GetPlayers()
	elseif rawTarget == "Self" or rawTarget == "self" or rawTarget == nil then
		return { admin }
	else
		local numId = tonumber(rawTarget)
		if Validation.Finite(numId) and numId>0 and numId%1==0 then
			local p = Players:GetPlayerByUserId(numId)
			if p then return { p } end
		end
		if typeof(rawTarget) == "string" then
			local lower = string.lower(rawTarget)
			for _, p in ipairs(Players:GetPlayers()) do
				if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
					return { p }
				end
			end
		end
	end
	return {}
end

local function filterText(player: Player, text: string): string?
 return Validation.FilterBroadcast(TextService,player.UserId,text)
end

local function commitAdmin(target, commands, reason)
 if target.Parent~=Players or target:GetAttribute("DataLoaded")~=true then return false end
 local handle=DataService.GetHandle(target.UserId)
 if not handle then return false end
 local ok,result=pcall(function()
  return DataService.Commit(handle,{operationId=DataService.NewOperationId(),fingerprint=reason,commands=commands})
 end)
 return ok and (result.kind=="Committed" or result.kind=="AlreadyCommitted")
end

local function reportTargets(admin, count, total, description)
 sendToast(admin,count>0,description..": "..count.."/"..total.." confirmed")
end

-- State for Auto Rebirths per admin
type AutoRebirthConfig = {
	enabled: boolean,
	mode: "Threshold" | "Forced",
	lastRun: number,
}
local autoRebirthAdmins: { [number]: AutoRebirthConfig } = {}

-- Auto Rebirth loop
task.spawn(function()
	while true do
		task.wait(1.0)
		for userId, cfg in pairs(autoRebirthAdmins) do
			if cfg.enabled then
				local player = Players:GetPlayerByUserId(userId)
				if player and player.Parent == Players then
					local now = os.clock()
					if cfg.mode == "Forced" then
						if now - cfg.lastRun >= 3.0 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, true)
							end
						end
					else
						-- Threshold mode: only rebirth if player meets level requirement
						local level = tonumber(player:GetAttribute("Level")) or 1
						local reqLevel = tonumber(player:GetAttribute("NextRebirthLevelRequired")) or 5
						if level >= reqLevel and now - cfg.lastRun >= 1.5 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, false)
							end
						end
					end
				else
					autoRebirthAdmins[userId] = nil
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	autoRebirthAdmins[player.UserId] = nil
end)

-- Apply pass state (enable or disable) for a target player
local function applyPassToggle(target: Player, passId: string, enabled: boolean): boolean
 local valid={VIP=true,Flight=true,TwoXSpeed=true,TwoXVictory=true,InfiniteRevives=true,DarkZonic=true,All=true}
 if not valid[passId] then return false end
 local commands={}
 for _,id in {"VIP","Flight","TwoXSpeed","TwoXVictory","InfiniteRevives","DarkZonic"} do
  if passId==id or passId=="All" then
   if id=="DarkZonic" then
    table.insert(commands,{kind=if enabled then "GrantSkin" else "RemoveSkin",skinId=id})
   else
    table.insert(commands,{kind=if enabled then "GrantUpgrade" else "RemoveUpgrade",upgradeId=id})
   end
   if id=="Flight" then table.insert(commands,{kind="SetAbilityEquipped",equipped=enabled}) end
   if id=="TwoXSpeed" then table.insert(commands,{kind="SetPersistent",key="PermanentBaseSpeedMultiplier",value=enabled and 2 or 1}) end
   -- TwoXVictory is the x2 pads pass: the saved TwoXVictory upgrade above is what
   -- StatsProjection reads on join. It no longer touches the Wins ladder multiplier.
  end
 end
 if not commitAdmin(target,commands,"admin_pass:"..passId..":"..tostring(enabled)) then return false end
 -- Session flags are applied only after the durable profile mutation confirms.
 if passId=="VIP" or passId=="All" then
  target:SetAttribute("VIPGamepassOwned",enabled)
  target:SetAttribute("VIPSpeedGainMultiplier",enabled and (tonumber(Config.VipSpeedGainMultiplier) or 2) or 1)
  target:SetAttribute("VIPWinsMultiplier",enabled and (tonumber(Config.VipWinsMultiplier) or 2) or 1)
 end
 if passId=="TwoXSpeed" or passId=="All" then target:SetAttribute("GamepassSpeedGainMultiplier",enabled and 2 or 1) end
 if passId=="TwoXVictory" or passId=="All" then
  target:SetAttribute("DoubleWinsPadUnlocked",enabled);target:SetAttribute("TwoXVictoryOwned",enabled)
 end
 if passId=="InfiniteRevives" or passId=="All" then
  target:SetAttribute("InfiniteRevivesOwned",enabled);target:SetAttribute("InfiniteRevivesOwnershipChecked",true)
 end
 if passId=="DarkZonic" or passId=="All" then target:SetAttribute("DarkZonicOwned",enabled) end
 if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
 if type(_G.SpeedsterRefreshAbilityShop)=="function" then _G.SpeedsterRefreshAbilityShop(target) end
 return true
end

local function redeemCodeForPlayers(codeName: string, force: boolean, senderName: string, eventId: string?): (number, number)
	local grantedCount = 0
	local alreadyCount = 0
	if type(_G.SpeedsterRedeemCode) ~= "function" then
		return 0, 0
	end
	for _, target in ipairs(Players:GetPlayers()) do
		local ok, msg = _G.SpeedsterRedeemCode(target, codeName, force, senderName, eventId)
		if ok then
			grantedCount += 1
		elseif msg == "AlreadyClaimed" then
			alreadyCount += 1
		end
	end
	return grantedCount, alreadyCount
end

pcall(function()
	MessagingService:SubscribeAsync(CODES_MESSAGING_TOPIC, function(message)
		local data = message.Data
		if Validation.Payload(data) and type(data.Code)=="string" and #data.Code<=64 then
   if data.OriginJobId==game.JobId then return end
   if not Validation.Finite(data.Timestamp) or math.abs(os.time()-data.Timestamp)>600 then return end
   if not acceptCodeEvent(data.EventId,os.time()) then return end
			redeemCodeForPlayers(data.Code, data.Force == true, data.SenderName or "Admin", data.EventId)
		end
	end)
end)

-- Character scaling for Tiny / Shrink commands
local function applyCharacterScale(character: Model, targetScale: number, duration: number?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)

	if not character:GetAttribute("OriginalScale") then
		character:SetAttribute("OriginalScale", 1.0)
	end

	-- For R15, update standard scale NumberValues
	if isR15 then
		for _, scaleName in { "BodyWidthScale", "BodyHeightScale", "BodyDepthScale", "HeadScale" } do
			local sc = humanoid:FindFirstChild(scaleName)
			if sc and sc:IsA("NumberValue") then
				sc.Value = targetScale
			end
		end
	end

	-- Universal Model:ScaleTo
	pcall(function()
		character:ScaleTo(targetScale)
	end)
	character:SetAttribute("AdminScale", targetScale)

	if duration and duration > 0 then
		local token = os.clock()
		character:SetAttribute("ScaleResetToken", token)
		task.delay(duration, function()
			if character.Parent and character:GetAttribute("ScaleResetToken") == token then
				if isR15 and humanoid.Parent then
					for _, scaleName in { "BodyWidthScale", "BodyHeightScale", "BodyDepthScale", "HeadScale" } do
						local sc = humanoid:FindFirstChild(scaleName)
						if sc and sc:IsA("NumberValue") then
							sc.Value = 1.0
						end
					end
				end
				pcall(function()
					character:ScaleTo(1.0)
				end)
				character:SetAttribute("AdminScale", 1.0)
			end
		end)
	end
end

-- 3000 Admin Treadmill Helpers
local spawnedAdminTreadmill: Model? = nil

local function getSpawnLocationCFrame(): CFrame
	local neworld1 = Workspace:FindFirstChild("neworld1")
	if neworld1 then
		local spawn = neworld1:FindFirstChild("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame * CFrame.new(0, 0, 25)
		end
	end
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("SpawnLocation") then
			return desc.CFrame * CFrame.new(0, 0, 20)
		end
	end
	return CFrame.new(280.28, 37466.56, -1755)
end

local function spawnAdminTreadmill(admin: Player): boolean
	if spawnedAdminTreadmill and spawnedAdminTreadmill.Parent then
		return true
	end

	-- Find treadmill template to clone (Hacker model or Admin model)
	local template: Instance? = nil
	local neworld1 = Workspace:FindFirstChild("neworld1")
	if neworld1 then
		template = neworld1:FindFirstChild("Hacker") or neworld1:FindFirstChild("Admin")
	end
	if not template then
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if desc:IsA("Model") and (desc.Name == "Hacker" or (desc:FindFirstChild("Treadmil", true) and desc.Name ~= "Admin3000")) then
				template = desc
				break
			end
		end
	end

	if not template then
		return false
	end

	local clone = template:Clone() :: Model
	clone.Name = "Admin3000"

	-- Highlight with radiant gold
	local hl = clone:FindFirstChildOfClass("Highlight")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Parent = clone
	end
	hl.FillColor = Color3.fromRGB(255, 215, 0)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.FillTransparency = 0.4
	hl.OutlineTransparency = 0.1

	-- Billboard label
	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local oldBb = primary:FindFirstChild("Admin3000Billboard")
		if oldBb then oldBb:Destroy() end

		local bb = Instance.new("BillboardGui")
		bb.Name = "Admin3000Billboard"
		bb.Size = UDim2.new(0, 260, 0, 80)
		bb.StudsOffset = Vector3.new(0, 7.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 150
		bb.Parent = primary

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 42)
		title.BackgroundTransparency = 1
		title.Text = "👑 ADMIN TREADMILL (+2%)"
		title.TextColor3 = Color3.fromRGB(255, 215, 0)
		title.Font = Enum.Font.FredokaOne
		title.TextSize = 18
		title.Parent = bb

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Color3.fromRGB(11, 27, 61)
		titleStroke.Thickness = 2.5
		titleStroke.Parent = title

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 28)
		sub.Position = UDim2.new(0, 0, 0, 38)
		sub.BackgroundTransparency = 1
		sub.Text = "x315 Speed (Top Treadmill)"
		sub.TextColor3 = Color3.fromRGB(240, 245, 255)
		sub.Font = Enum.Font.FredokaOne
		sub.TextSize = 14
		sub.Parent = bb

		local subStroke = Instance.new("UIStroke")
		subStroke.Color = Color3.fromRGB(11, 27, 61)
		subStroke.Thickness = 2
		subStroke.Parent = sub
	end

	local targetCF = getSpawnLocationCFrame()
	pcall(function()
		local spawnPart = (neworld1 and neworld1:FindFirstChild("SpawnLocation"))
			or Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local floorY = spawnPart and (spawnPart.Position.Y + (spawnPart.Size.Y / 2)) or targetCF.Position.Y

		-- Compute bottom of clone model using GetBoundingBox so it rests cleanly on top of the floor
		local _, modelSize = clone:GetBoundingBox()
		local centerTargetY = floorY + (modelSize.Y / 2) + 0.1
		local finalCF = CFrame.new(targetCF.Position.X, centerTargetY, targetCF.Position.Z) * (targetCF - targetCF.Position)
		clone:PivotTo(finalCF)
	end)

	if neworld1 then
		clone.Parent = neworld1
	else
		clone.Parent = Workspace
	end

	spawnedAdminTreadmill = clone
	return true
end

local function despawnAdminTreadmill(): boolean
	local found = false
	if spawnedAdminTreadmill and spawnedAdminTreadmill.Parent then
		spawnedAdminTreadmill:Destroy()
		spawnedAdminTreadmill = nil
		found = true
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Admin3000" then
			child:Destroy()
			found = true
		end
	end
	local neworld1 = Workspace:FindFirstChild("neworld1")
	if neworld1 then
		for _, child in ipairs(neworld1:GetChildren()) do
			if child.Name == "Admin3000" then
				child:Destroy()
				found = true
			end
		end
	end
	return found
end

local TREADMILL_NAMES: { [string]: boolean } = {
	Treadmill1_basic = true,
	Treadmill2_fast = true,
	Treadmill3_superfast = true,
	Treadmill4_hyperspeed = true,
	Treadmill5_insanespeed = true,
}

local spawnedTreadmillFolder = Workspace:FindFirstChild("OwnerSpawnedTreadmills")
if not spawnedTreadmillFolder then
	spawnedTreadmillFolder = Instance.new("Folder")
	spawnedTreadmillFolder.Name = "OwnerSpawnedTreadmills"
	spawnedTreadmillFolder.Parent = Workspace
end

local function findTreadmillTemplate(exactName: string): Instance?
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == exactName and (obj:IsA("Model") or obj:IsA("BasePart")) and not obj:IsDescendantOf(spawnedTreadmillFolder) then
			return obj
		end
	end
	return nil
end

local function spawnTreadmillUnderPlayer(player: Player, treadmillName: string): (boolean, string)
	if not TREADMILL_NAMES[treadmillName] then
		return false, "Unrecognized treadmill: " .. tostring(treadmillName)
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, "Your character is not ready"
	end

	local source = findTreadmillTemplate(treadmillName)
	if not source then
		return false, "Could not find " .. treadmillName .. " on the map"
	end

	local ok, clone = pcall(function() return source:Clone() end)
	if not ok or not clone then
		return false, "Error cloning " .. treadmillName
	end

	clone.Name = treadmillName
	clone:SetAttribute("OwnerAdminSpawned", true)
	clone:SetAttribute("OwnerAdminSpawnedBy", player.UserId)

	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		elseif part:IsA("LuaSourceContainer") then
			part:Destroy()
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
	end

	clone.Parent = spawnedTreadmillFolder

	local boxCF, boxSize
	local bOk = pcall(function()
		if clone:IsA("Model") then
			boxCF, boxSize = clone:GetBoundingBox()
		else
			boxCF, boxSize = clone.CFrame, clone.Size
		end
	end)

	if bOk and boxCF and boxSize then
		local feetY = root.Position.Y - (hum.HipHeight or 2) - (root.Size.Y * 0.5)
		local targetCenter = Vector3.new(root.Position.X, feetY - (boxSize.Y * 0.5) + 0.05, root.Position.Z)
		local targetBoxCF = CFrame.new(targetCenter) * boxCF.Rotation
		pcall(function()
			if clone:IsA("Model") then
				clone:PivotTo(targetBoxCF)
			else
				clone.CFrame = targetBoxCF
			end
		end)
	end

	return true, "Caminadora " .. treadmillName .. " colocada bajo tus pies!"
end

local GRANT_SUFFIXES: { [string]: number } = {
	k = 1e3, m = 1e6, b = 1e9, t = 1e12,
	qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24,
	oc = 1e27, no = 1e30, dc = 1e33,
}

local function parseGrantAmount(raw: any, statName: string?): number?
	local text = tostring(raw or ""):lower():gsub("[%s,_]", "")
	local amount = tonumber(text)
	if not amount then
		local numberText, suffix = text:match("^([%d%.]+)([%a]+)$")
		local multiplier = suffix and GRANT_SUFFIXES[suffix]
		if numberText and multiplier then
			amount = tonumber(numberText) * multiplier
		end
	end
	if not amount or amount ~= amount or amount <= 0 or amount == math.huge or amount == -math.huge then
		return nil
	end
	if statName == "Wins" or statName == "Rebirths" then
		amount = math.floor(amount)
	end
	return amount
end

-- Server request listener
AdminPanelAction.OnServerEvent:Connect(function(player: Player, payload: any)
 if not RateLimiter.Allow(player,"AdminPanelRequest",0.25) then return end
 if not Validation.Payload(payload) then return end
 if not isAllowed(player) then
  AdminPanelStatus:FireClient(player,{kind="Permission",allowed=false});return
 end
 local action=payload.action or payload.Action
 if type(action)~="string" or #action>40 then return end
 if action~="CheckPermission" and not RateLimiter.Allow(player,"AdminPanelMutation",1) then sendToast(player,false,"Please wait a second before the next action.");return end
 if payload.target~=nil and #resolveTargets(player,payload.target)==0 then sendToast(player,false,"Target not found");return end

	if action == "CheckPermission" then
		local boostExp = tonumber(Workspace:GetAttribute("ServerBoostExpiresUnix")) or 0
		local remainingBoost = math.max(0, boostExp - os.time())
		local cfg = autoRebirthAdmins[player.UserId]
		local tmActive = (spawnedAdminTreadmill ~= nil and spawnedAdminTreadmill.Parent ~= nil) or Workspace:FindFirstChild("Admin3000", true) ~= nil
		AdminPanelStatus:FireClient(player, {
			kind = "Permission",
			allowed = true,
			displayName = player.DisplayName,
			serverBoostRemaining = remainingBoost,
			autoRebirthEnabled = cfg and cfg.enabled == true or false,
			autoRebirthMode = cfg and cfg.mode or "Threshold",
			world2Unlocked = player:GetAttribute("World2Unlocked") == true,
			adminTreadmillActive = tmActive,
		})

	elseif action == "ServerBoost" or action == "ServerMultiplierBoost" then
		local minutes = math.clamp(math.floor(tonumber(payload.minutes) or 15), 1, 240)
		local mult = math.clamp(math.floor(tonumber(payload.multiplier) or 2), 1, 20)
		local statType = tostring(payload.statType or "Both") -- "Both", "Speed", "Wins"

		if statType == "Both" or statType == "Speed" then
			local grant = PotionServer.GrantServerBoost(minutes, mult, player.DisplayName)
			if grant and grant.Notify then
				grant.Notify()
			end
		end

		if statType == "Both" or statType == "Wins" then
			for _, p in ipairs(Players:GetPlayers()) do
				pcall(function()
					local winGrant = PotionServer.GrantWinsPotion(p, minutes, mult)
					if winGrant and winGrant.Notify then
						winGrant.Notify()
					end
				end)
			end
		end

		local statDesc = if statType == "Both" then "Speed & Wins" elseif statType == "Speed" then "Speed" else "Wins"
		sendToast(player, true, "⚡ Boost " .. mult .. "x " .. statDesc .. " activated for the server for " .. minutes .. "m!")

	elseif action == "ToggleAdminTreadmill" then
		local shouldSpawn = payload.spawn
		local currentlySpawned = (spawnedAdminTreadmill ~= nil and spawnedAdminTreadmill.Parent ~= nil) or Workspace:FindFirstChild("Admin3000", true) ~= nil
		if shouldSpawn == nil then
			shouldSpawn = not currentlySpawned
		end

		if shouldSpawn then
			local ok = spawnAdminTreadmill(player)
			if ok then
				sendToast(player, true, "👑 Admin Treadmill 3000 (+2% Speed) spawned at Spawn!")
			else
				sendToast(player, false, "Could not find treadmill template to clone.")
			end
		else
			despawnAdminTreadmill()
			sendToast(player, true, "🗑️ Admin Treadmill 3000 removed from the map.")
		end

		local newState = (spawnedAdminTreadmill ~= nil and spawnedAdminTreadmill.Parent ~= nil) or Workspace:FindFirstChild("Admin3000", true) ~= nil
		for _, p in ipairs(Players:GetPlayers()) do
			if isAllowed(p) then
				AdminPanelStatus:FireClient(p, {
					kind = "AdminTreadmillState",
					active = newState,
				})
			end
		end

	elseif action == "SpawnTreadmill" then
		local tmName = tostring(payload.Treadmill or payload.treadmill or "")
		if tmName == "Admin3000" then
			local ok = spawnAdminTreadmill(player)
			sendToast(player, ok, ok and "👑 Admin Treadmill 3000 spawned at Spawn!" or "Could not find treadmill template to clone.")
		else
			local ok, msg = spawnTreadmillUnderPlayer(player, tmName)
			sendToast(player, ok, msg)
		end

	elseif action == "SetFly" then
		local enabled = payload.enabled == true or payload.Enabled == true
		-- The game's own Flight; AdminFlying was the retired panel's flight loop, and set on
		-- its own it stops Flight and normal movement.
		player:SetAttribute("AdminFlying", false)
		if enabled and type(_G.SpeedsterGrantFlight) == "function" then
			pcall(_G.SpeedsterGrantFlight, player, "admin_panel_fly")
		end
		sendToast(player, true, "Flight Mode: " .. (enabled and "ENABLED" or "DISABLED"))

	elseif action == "Grant" then
		local stat = tostring(payload.Stat or payload.stat or "Speed")
		if stat ~= "Speed" and stat ~= "Wins" and stat ~= "Rebirths" then
			stat = "Speed"
		end
		local rawAmount = payload.Amount or payload.amount or 1
		local parsed = parseGrantAmount(rawAmount, stat)
		if not parsed then
			sendToast(player, false, "Invalid amount. Example: 50000, 2M, 1e15")
			return
		end
		local scope = tostring(payload.Scope or payload.scope or "Server")
		local targets
		if payload.target and payload.target ~= "All" then
			targets = resolveTargets(player, payload.target)
		elseif scope == "Global" or scope == "Server" then
			targets = Players:GetPlayers()
		else
			targets = { player }
		end
		local confirmed = 0
		for _, target in ipairs(targets) do
			if commitAdmin(target, { { kind = "GrantExact", stat = stat, amount = parsed } }, "admin_grant:" .. stat .. ":" .. parsed) then
				confirmed += 1
				if type(_G.SpeedsterApplyWalkSpeed) == "function" then _G.SpeedsterApplyWalkSpeed(target) end
				if target ~= player then sendToast(target, true, "Admin granted +" .. parsed .. " " .. stat) end
			end
		end
		reportTargets(player, confirmed, #targets, "+" .. parsed .. " " .. stat)

	elseif action == "RagdollPlayers" or action == "RagdollEveryone" then
		local dur = math.clamp(math.floor(tonumber(payload.duration) or 5), 1, 60)
		local targets = resolveTargets(player, payload.target or "All")
		local count = 0
		for _, target in ipairs(targets) do
			local char = target.Character
			if char and char.Parent then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local ragdollEvent = char:FindFirstChild("RagdollEvent")
					if ragdollEvent and ragdollEvent:IsA("BindableEvent") then
						ragdollEvent:Fire("Ragdoll", dur)
					else
						char:SetAttribute("RagdollDuration", dur)
						char:SetAttribute("Ragdolled", true)
					end
					count += 1
				end
			end
		end
		sendToast(player, true, "💫 Ragdoll aplicado a " .. count .. "/" .. #targets .. " jugadores (" .. dur .. "s)")

	elseif action == "UnragdollPlayers" or action == "UnragdollEveryone" then
		local targets = resolveTargets(player, payload.target or "All")
		local count = 0
		for _, target in ipairs(targets) do
			local char = target.Character
			if char and char.Parent then
				local ragdollEvent = char:FindFirstChild("RagdollEvent")
				if ragdollEvent and ragdollEvent:IsA("BindableEvent") then
					ragdollEvent:Fire("Unragdoll")
				else
					char:SetAttribute("Ragdolled", false)
				end
				count += 1
			end
		end
		sendToast(player, true, "🧍 Unragdoll aplicado a " .. count .. " jugadores")

	elseif action == "TinyPlayers" or action == "TinyEveryone" then
		local scale = math.clamp(tonumber(payload.scale) or 0.5, 0.2, 2.0)
		local dur = math.clamp(math.floor(tonumber(payload.duration) or 30), 1, 300)
		local targets = resolveTargets(player, payload.target or "All")
		local count = 0
		for _, target in ipairs(targets) do
			local char = target.Character
			if char and char.Parent then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					applyCharacterScale(char, scale, dur)
					count += 1
				end
			end
		end
		sendToast(player, true, "🐣 Tiny (" .. scale .. "x) applied to " .. count .. "/" .. #targets .. " players for " .. dur .. "s")

	elseif action == "ResetScale" then
		local targets = resolveTargets(player, payload.target or "All")
		local count = 0
		for _, target in ipairs(targets) do
			local char = target.Character
			if char and char.Parent then
				applyCharacterScale(char, 1.0, 0)
				count += 1
			end
		end
		sendToast(player, true, "🧍 Normal size restored for " .. count .. " players")

	elseif action == "GekoFlyGiveaway" then
  local targets=resolveTargets(player,payload.target or "All")
  local minutes=math.clamp(math.floor(tonumber(payload.minutes) or 20),1,120)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{
    {kind="GrantExact",stat="Speed",amount=800000},
    {kind="GrantExact",stat="Wins",amount=20000},
    {kind="GrantBuff",grant={kind="TemporaryFlight",addedSeconds=minutes*60}},
   },"admin_gekkoh:"..minutes) then
    confirmed+=1
    if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
    if type(_G.SpeedsterRefreshAbilityShop)=="function" then _G.SpeedsterRefreshAbilityShop(target) end
    sendToast(target,true,"Gekkoh gave you +800K Speed, +20K Wins and "..minutes.."m Flight!")
   end
  end
  reportTargets(player,confirmed,#targets,"Gekkoh giveaway")

 elseif action=="GiveRebirths" or action=="GiveStats" or action=="ServerGiveStats" then
  if action=="GiveStats" and payload.stat~="Speed" and payload.stat~="Wins" and payload.stat~="Rebirths" then sendToast(player,false,"Invalid stat");return end
  local stat=if action=="GiveRebirths" then "Rebirths" else payload.stat
  local limit=if stat=="Rebirths" then 10000 else 1e14
  local amount=math.clamp(math.floor(tonumber(payload.amount) or 1),1,limit)
  local targets=resolveTargets(player,payload.target or "All")
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{{kind="GrantExact",stat=stat,amount=amount}},"admin_grant:"..stat..":"..amount) then
    confirmed+=1
    if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
    if target~=player then sendToast(target,true,"Admin granted +"..amount.." "..stat) end
   end
  end
  reportTargets(player,confirmed,#targets,"+"..amount.." "..stat)

 elseif action=="TogglePass" then
  if type(payload.pass)~="string" or type(payload.enabled)~="boolean" then sendToast(player,false,"Invalid pass request");return end
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if applyPassToggle(target,payload.pass,payload.enabled) then
    confirmed+=1
    if target~=player then sendToast(target,true,"Admin updated "..payload.pass) end
   end
  end
  reportTargets(player,confirmed,#targets,"Pass "..payload.pass)

	elseif action == "AutoRebirth" then
		local enabled = payload.enabled == true
		local mode = if payload.mode == "Forced" then "Forced" else "Threshold"

		autoRebirthAdmins[player.UserId] = {
			enabled = enabled,
			mode = mode,
			lastRun = 0,
		}

		local modeText = if mode == "Forced" then "Fast (every 3s, resets stats)" else "Upon reaching required level"
		sendToast(player, true, "🔄 Auto Rebirth: " .. (enabled and "ENABLED [" .. modeText .. "]" or "DISABLED"))

	elseif action == "ManualRebirthReset" then
		if type(_G.SpeedsterPerformRebirth) == "function" then
			_G.SpeedsterPerformRebirth(player, true)
			sendToast(player, true, "✨ Forced Rebirth completed! Stats reset to 1 and +1 Rebirth.")
		else
			sendToast(player, false, "RebirthSystem not available.")
		end

 elseif action=="UnlockWorld2" then
  local enabled=payload.enabled~=false
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{{kind="SetPersistent",key="World2Unlocked",value=enabled,allowFalse=true}},"admin_world2:"..tostring(enabled)) then confirmed+=1 end
  end
  reportTargets(player,confirmed,#targets,"World 2 "..(enabled and "unlocked" or "locked"))

	elseif action == "TeleportWorld1" or action == "TeleportWorld2" or action == "TeleportWorld3" then
		if type(_G.SpeedsterAdminWorldTravel)=="function" then
			_G.SpeedsterAdminWorldTravel(player, tonumber(string.sub(action, -1)))
		else sendToast(player,false,"World travel is still loading") end

	elseif action == "BroadcastAnnouncement" then
		local rawMsg = type(payload.message)=="string" and payload.message or ""
		local trimmed = string.match(rawMsg, "^%s*(.-)%s*$") or ""
		if #trimmed == 0 then
			sendToast(player, false, "Message cannot be empty.")
			return
		end
		if #trimmed > 250 then trimmed = string.sub(trimmed, 1, 250) end

		local filtered = filterText(player, trimmed)
		if not filtered then sendToast(player,false,"Text filtering unavailable; announcement was not sent");return end
		local annPayload = {
			Message = filtered,
			EventId=HttpService:GenerateGUID(false),
			OriginJobId=game.JobId,
			SenderName = player.DisplayName or player.Name,
			SenderId = player.UserId,
			Duration = 8,
			Timestamp = os.time(),
		}

		DisplayRemote:FireAllClients(annPayload)

		if not RunService:IsStudio() then
			task.spawn(function()
				pcall(function()
					MessagingService:PublishAsync(MESSAGING_TOPIC, annPayload)
				end)
			end)
		end

		sendToast(player, true, "📢 Global announcement broadcasted to all.")

	elseif action == "ActivateCode" then
		local rawCode = type(payload.code)=="string" and payload.code or ""
		local cleanCode = string.match(rawCode, "^%s*(.-)%s*$") or ""
		if #cleanCode == 0 then
			sendToast(player, false, "Code cannot be empty.")
			return
		end

		local definition = CodesCatalog.Get(cleanCode)
		if not definition then
			sendToast(player, false, "Code '" .. cleanCode .. "' does not exist in the catalog.")
			return
		end

		local scope = tostring(payload.scope or "Server")
		local force = payload.force == true
		local senderName = player.DisplayName or player.Name

		local codeEventId=HttpService:GenerateGUID(false)
		local granted, already = redeemCodeForPlayers(cleanCode, force, senderName, codeEventId)

		if scope == "Global" then
			local codePayload = {
				Code = cleanCode,
				EventId = codeEventId,
				OriginJobId = game.JobId,
				SenderName = senderName,
				SenderId = player.UserId,
				Force = force,
				Timestamp = os.time(),
			}

			if not RunService:IsStudio() then
				task.spawn(function()
					pcall(function()
						MessagingService:PublishAsync(CODES_MESSAGING_TOPIC, codePayload)
					end)
				end)
			end

			sendToast(player, true, "🌐 Code [" .. cleanCode .. "] ACTIVATED GLOBALLY (" .. granted .. " in this server)")
		else
			local resultMsg = "✅ Code [" .. cleanCode .. "] activated: " .. granted .. " granted"
			if already > 0 then
				resultMsg = resultMsg .. ", " .. already .. " already had it"
			end
			sendToast(player, true, resultMsg)
		end
	end
end)

-- Player joining setup: Set AdminCommands attribute so clients know status immediately
local function setupPlayerAdmin(player: Player)
	player:SetAttribute("AdminCommands", isAllowed(player))
end

Players.PlayerAdded:Connect(setupPlayerAdmin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayerAdmin, p)
end

-- Reset Character handler: Ensures reliable kill on reset request
local playerResetRemote = ensureRemote("PlayerResetRequest")
playerResetRemote.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end)

-- Chat command listener (;admin, /admin, :admin, ;panel, /panel)
local function handleServerChat(player: Player, msg: string)
	if not isAllowed(player) then return end
	local text = string.lower(string.gsub(msg, "^%s+", ""))
	local firstWord = string.split(text, " ")[1] or ""
	if firstWord == ";admin"
		or firstWord == "/admin"
		or firstWord == ":admin"
		or firstWord == "!admin"
		or firstWord == "admin"
		or firstWord == ";panel"
		or firstWord == "/panel"
		or firstWord == ":panel"
		or firstWord == "!panel"
		or firstWord == "panel"
	then
		AdminPanelStatus:FireClient(player, { kind = "OpenUI" })
	end
end

local function hookChatForPlayer(player: Player)
	player.Chatted:Connect(function(msg)
		handleServerChat(player, msg)
	end)
end

Players.PlayerAdded:Connect(hookChatForPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	hookChatForPlayer(p)
end

pcall(function()
	local TextChatService = game:GetService("TextChatService")
	TextChatService.MessageReceived:Connect(function(textChatMessage)
		local source = textChatMessage.TextSource
		if not source then return end
		local p = Players:GetPlayerByUserId(source.UserId)
		if p then
			handleServerChat(p, textChatMessage.Text)
		end
	end)
end)

print("[AdminPanelService] Loaded successfully. Authorized admins have full control.")
