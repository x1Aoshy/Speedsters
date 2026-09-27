         
                                                    
                                                                       
                                                                               
                                                                    

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local function isPlayerAdmin(player: Player): boolean
	if RunService:IsStudio() then return true end
	if player.UserId == 767108248 or player.UserId == 111827288 or player.UserId == 5113549114 then return true end
	if AdminBannerConfig and AdminBannerConfig.IsAdmin(player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local WORLD_1_PLACE_ID = Config.World1PlaceId or 85065221510105
local WORLD_2_PLACE_ID = Config.World2PlaceId or 116359653478954
local WORLD_3_PLACE_ID = Config.World3PlaceId or 128432111599629
local WORLD_2_COMING_SOON = false
-- World 2: the first trip (or the auto-unlock) needs these; World2Unlocked keeps it open.
-- 2026-09-22: read from Config like World 3's, so the gate is one Config edit.
local WORLD_2_REBIRTH_REQUIREMENT = math.max(0, math.floor(tonumber(Config.World2UnlockRebirths) or 6))
local WORLD_2_LEVEL_REQUIREMENT = math.max(1, math.floor(tonumber(Config.World2UnlockLevel) or 50))
-- World 3 (Desert): the first trip needs these; World3Unlocked keeps it open afterwards.
local WORLD_3_REBIRTH_REQUIREMENT = math.max(0, math.floor(tonumber(Config.World3UnlockRebirths) or 15))
local WORLD_3_LEVEL_REQUIREMENT = math.max(1, math.floor(tonumber(Config.World3UnlockLevel) or 200))
-- Until Config.World3PlaceId is set, World 3 is found among the game's places by name.
local WORLD_3_PLACE_NAMES = { world3 = true, worldthree = true, desert = true, desertworld = true, world3desert = true }
local WORLD_3_LOOKUP_RETRY_SECONDS = 60
local PORTAL_NAME = "PortalWorld2"
local TOUCH_COOLDOWN = 1.25
local ACTION_COOLDOWN = 0.35
local PORTAL_ACCESS_SECONDS = 30
local PORTAL_EXTRA_DISTANCE = 12

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldPortalAction = Remotes:WaitForChild("WorldPortalAction")
local WorldPortalUpdate = Remotes:WaitForChild("WorldPortalUpdate")

local connectedParts = setmetatable({}, { __mode = "k" })
local lastTouchAt = {}
local lastActionAt = {}
local lastPortalPart = {}
local teleporting = {}

local world1PlaceId = nil
local world1ResolutionFinished = false
local world1ResolutionError = nil
local resolvingWorld1 = false

local function currentWorld()
	if Config.IsWorld3Place then
		return 3
	end
	if Config.IsWorld2Place then
		return 2
	end
	return (game.PlaceId == WORLD_2_PLACE_ID or game.PlaceId == 96501592055150 or game.PlaceId == 116359653478954) and 2
		or (game.PlaceId == WORLD_3_PLACE_ID or game.PlaceId == 94956471703437) and 3
		or 1
end

local function normalizedPlaceName(value)
	return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function resolveWorld1PlaceId()
	if world1ResolutionFinished then
		return world1PlaceId
	end

	if currentWorld() ~= 1
		or game.PlaceId == WORLD_2_PLACE_ID
		or game.PlaceId == 96501592055150
		or game.PlaceId == 116359653478954
		or game.PlaceId == WORLD_3_PLACE_ID
		or game.PlaceId == 94956471703437
	then
		world1PlaceId = WORLD_1_PLACE_ID
		world1ResolutionFinished = true
		return world1PlaceId
	end

	if game.PlaceId > 0
		and game.PlaceId ~= WORLD_2_PLACE_ID
		and game.PlaceId ~= 96501592055150
		and game.PlaceId ~= 116359653478954
		and game.PlaceId ~= WORLD_3_PLACE_ID
		and game.PlaceId ~= 94956471703437
	then
		world1PlaceId = game.PlaceId
		world1ResolutionFinished = true
		return world1PlaceId
	end

	if resolvingWorld1 then
		local deadline = os.clock() + 15
		while resolvingWorld1 and os.clock() < deadline do
			task.wait()
		end
		return world1PlaceId
	end

	resolvingWorld1 = true
	local candidates = {}
	local preferred = nil
	local ok, err = pcall(function()
		local pages = AssetService:GetGamePlacesAsync()
		while true do
			for _, place in ipairs(pages:GetCurrentPage()) do
				local placeId = math.floor(tonumber(place.PlaceId) or 0)
				if placeId > 0 and placeId ~= WORLD_2_PLACE_ID then
					table.insert(candidates, placeId)
					local name = normalizedPlaceName(place.Name)
					if name == "world1"
						or name == "worldone"
						or name == "startplace"
						or name == "startingplace"
					then
						preferred = placeId
					end
				end
			end

			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)

	if ok then
		if preferred then
			world1PlaceId = preferred
		elseif #candidates == 1 then
			                                                                      
			                                              
			world1PlaceId = candidates[1]
		else
			world1ResolutionError = "World 1 could not be identified unambiguously"
		end
	else
		world1ResolutionError = "World 1 lookup failed: " .. tostring(err)
	end

	resolvingWorld1 = false
	world1ResolutionFinished = true
	if not world1PlaceId then
		warn("[WorldPortalService] " .. tostring(world1ResolutionError))
	end
	return world1PlaceId
end

local world3PlaceId = nil
local world3LookupAt = -math.huge
local world3Looking = false

-- World 3's place: Config.World3PlaceId, else the one place in this game named like
-- "World 3" or "Desert". Nil while it does not exist yet.
local function resolveWorld3PlaceId()
	local configured = math.floor(tonumber(Config.World3PlaceId) or 0)
	if configured > 0 then
		return configured
	end
	if currentWorld() == 3 and game.PlaceId > 0 then
		return game.PlaceId
	end
	if world3PlaceId or world3Looking or os.clock() - world3LookupAt < WORLD_3_LOOKUP_RETRY_SECONDS then
		return world3PlaceId
	end
	world3Looking = true
	world3LookupAt = os.clock()
	local found = {}
	pcall(function()
		local pages = AssetService:GetGamePlacesAsync()
		while true do
			for _, place in ipairs(pages:GetCurrentPage()) do
				local placeId = math.floor(tonumber(place.PlaceId) or 0)
				if placeId > 0 and WORLD_3_PLACE_NAMES[normalizedPlaceName(place.Name)] then
					table.insert(found, placeId)
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	world3Looking = false
	if #found == 1 then
		world3PlaceId = found[1]
	elseif #found > 1 then
		warn("[WorldPortalService] More than one place looks like World 3; set Config.World3PlaceId")
	end
	return world3PlaceId
end

local function getLeaderstat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return value and tonumber(value.Value) or 0
end

local function getLevel(player)
	local level = tonumber(player:GetAttribute("Level"))
	if level then
		return math.max(1, math.floor(level))
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	local value = dataFolder and dataFolder:FindFirstChild("Level")
	return math.max(1, math.floor(tonumber(value and value.Value) or 1))
end

local function makeState(player, message, openMenu, status)
	local level = getLevel(player)
	local rebirths = math.max(0, math.floor(getLeaderstat(player, "Rebirths")))
	local unlocked = player:GetAttribute("World2Unlocked") == true
	local unlocked3 = player:GetAttribute("World3Unlocked") == true
	return {
		CurrentWorld = currentWorld(),
		World2ComingSoon = WORLD_2_COMING_SOON,
		World2Unlocked = unlocked,
		Level = level,
		Rebirths = rebirths,
		RequiredLevel = WORLD_2_LEVEL_REQUIREMENT,
		RequiredRebirths = WORLD_2_REBIRTH_REQUIREMENT,
		MeetsWorld2Requirements = unlocked
			or isPlayerAdmin(player)
			or (level >= WORLD_2_LEVEL_REQUIREMENT and rebirths >= WORLD_2_REBIRTH_REQUIREMENT),
		World3Unlocked = unlocked3,
		World3RequiredLevel = WORLD_3_LEVEL_REQUIREMENT,
		World3RequiredRebirths = WORLD_3_REBIRTH_REQUIREMENT,
		MeetsWorld3Requirements = unlocked3
			or isPlayerAdmin(player)
			or (level >= WORLD_3_LEVEL_REQUIREMENT and rebirths >= WORLD_3_REBIRTH_REQUIREMENT),
		World3Ready = currentWorld() == 3 or world3PlaceId ~= nil or (tonumber(Config.World3PlaceId) or 0) > 0,
		World1Ready = currentWorld() == 1 or world1PlaceId ~= nil,
		DataReady = player:GetAttribute("DataLoaded") == true,
		Busy = teleporting[player] ~= nil,
		Message = tostring(message or ""),
		OpenMenu = openMenu == true,
		Status = tostring(status or "State"),
	}
end

local function sendState(player, message, openMenu, status)
	if player.Parent == Players then
		WorldPortalUpdate:FireClient(player, makeState(player, message, openMenu, status))
	end
end

local function getPlayerFromTouch(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil
	end

	local ancestor = hit.Parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(ancestor)
			if player then
				local humanoid = ancestor:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					return player
				end
				return nil
			end
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function portalAncestor(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == PORTAL_NAME and (current:IsA("BasePart") or current:IsA("Model")) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function playerIsNearLastPortal(player)
	local touchedAt = lastTouchAt[player]
	local part = lastPortalPart[player]
	if not touchedAt or os.clock() - touchedAt > PORTAL_ACCESS_SECONDS then
		return false
	end
	if not part or not part.Parent or not part:IsDescendantOf(Workspace) then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local radius = math.max(18, math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5 + PORTAL_EXTRA_DISTANCE)
	return (root.Position - part.Position).Magnitude <= radius
end

local function onPortalTouched(portalPart, hit)
	local player = getPlayerFromTouch(hit)
	if not player or teleporting[player] then
		return
	end

	local now = os.clock()
	if now - (lastTouchAt[player] or -math.huge) < TOUCH_COOLDOWN then
		return
	end

	lastTouchAt[player] = now
	lastPortalPart[player] = portalPart
	if currentWorld() ~= 1 and not world1ResolutionFinished then
		task.spawn(resolveWorld1PlaceId)
	end
	if currentWorld() ~= 3 then
		task.spawn(resolveWorld3PlaceId)
	end

	sendState(player, "Choose a world", true, "Touched")
end

local function connectPortalPart(part)
	if connectedParts[part] or not part:IsA("BasePart") then
		return
	end
	if not portalAncestor(part) then
		return
	end

	connectedParts[part] = true
	part.CanTouch = true
	part.Touched:Connect(function(hit)
		onPortalTouched(part, hit)
	end)
end

local function registerPortalCandidate(instance)
	if instance:IsA("BasePart") then
		if instance.Name == PORTAL_NAME or portalAncestor(instance) then
			connectPortalPart(instance)
		end
	elseif instance:IsA("Model") and instance.Name == PORTAL_NAME then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				connectPortalPart(descendant)
			end
		end
	end
end

local portalPartCount = 0
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant.Name == PORTAL_NAME then
		registerPortalCandidate(descendant)
	end
end
for _ in pairs(connectedParts) do
	portalPartCount += 1
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == PORTAL_NAME or portalAncestor(descendant) then
		registerPortalCandidate(descendant)
	end
end)

if currentWorld() == 1 then
	resolveWorld1PlaceId()
else
	task.spawn(resolveWorld1PlaceId)
end

local function saveForTeleport(player)
	local saveFunction = _G.SpeedsterSavePlayer
	if type(saveFunction) ~= "function" then
		return false, "The save service is still starting"
	end

	local ok, result = pcall(saveFunction, player, "teleport", true)
	if not ok then
		return false, tostring(result)
	end
	if result ~= true then
		return false, "Your progress could not be saved safely"
	end
	return true
end

local function reclaimSessionAfterFailedTeleport(player)
	local saveFunction = _G.SpeedsterSavePlayer
	if player.Parent == Players and type(saveFunction) == "function" then
		local ok, result = pcall(saveFunction, player, "teleport_recover", true)
		if not ok or result ~= true then
			warn("[WorldPortalService] Could not reclaim save session for " .. player.Name)
			return false
		end
	end
	return true
end

local function failTeleport(player, message, attempt)
	if attempt and teleporting[player] ~= attempt then
		return
	end
	player:SetAttribute("CrossPlaceTeleporting", false)
	                                                                            
	                                                         
	local recovered = reclaimSessionAfterFailedTeleport(player)
	teleporting[player] = nil
	if recovered then
		sendState(player, message, false, "Error")
	elseif player.Parent == Players then
		player:Kick("Your teleport did not start and your save session could not be restored safely. Please rejoin; your last confirmed save is protected.")
	end
end

local function armTeleportTimeout(player, attempt)
	task.delay(30, function()
		if player.Parent == Players and teleporting[player] == attempt then
			failTeleport(player, "Teleport timed out. Please touch the portal and try again.", attempt)
		end
	end)
end

local function isPlayerAllowedToTravel(player, destinationWorld)
	if isPlayerAdmin(player) then
		return true
	end
	-- World 1 is the starting world: players in World 2 are always permitted to return to World 1
	if destinationWorld == 1 and currentWorld() == 2 then
		return true
	end
	-- Leaving World 3 for an earlier world is always allowed.
	if currentWorld() == 3 and destinationWorld < 3 then
		return true
	end

	-- Check if player touched any portal recently (within 120s)
	local touchedAt = lastTouchAt[player]
	if touchedAt and (os.clock() - touchedAt) <= 120 then
		return true
	end

	-- Check proximity to any connected portal part in Workspace
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		for part in pairs(connectedParts) do
			if part and part.Parent and part:IsDescendantOf(Workspace) then
				local radius = math.max(35, math.max(part.Size.X, part.Size.Y, part.Size.Z) * 1.5 + 25)
				if (root.Position - part.Position).Magnitude <= radius then
					return true
				end
			end
		end
	end

	return false
end

local function handlePortalAction(player, action, destinationWorld, trustedAdmin)
	if action == "RequestState" then
		sendState(player, "Choose a world", false, "State")
		return
	end
	if action ~= "Travel" then
		return
	end

	local now = os.clock()
	if now - (lastActionAt[player] or -math.huge) < ACTION_COOLDOWN then
		return
	end
	lastActionAt[player] = now

	destinationWorld = math.floor(tonumber(destinationWorld) or 0)
	if destinationWorld ~= 1 and destinationWorld ~= 2 and destinationWorld ~= 3 then
		return
	end
	if teleporting[player] then
		sendState(player, "Teleport already starting...", false, "Busy")
		return
	end
	if not trustedAdmin and not isPlayerAllowedToTravel(player, destinationWorld) then
		sendState(player, "Touch PortalWorld2 again to travel", false, "Error")
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		sendState(player, "Your data is still loading", false, "Error")
		return
	end
	if destinationWorld == currentWorld() then
		sendState(player, "You are already in World " .. tostring(destinationWorld), false, "Current")
		return
	end
	if destinationWorld == 2 and WORLD_2_COMING_SOON then
		sendState(player, "World 2 is coming soon", false, "ComingSoon")
		return
	end

	local newlyUnlocked = false
	-- Anyone in World 3 already earned World 2.
	if destinationWorld == 2 and currentWorld() ~= 3 and player:GetAttribute("World2Unlocked") ~= true then
		if isPlayerAdmin(player) then
			player:SetAttribute("World2Unlocked", true)
			local DataService = require(game:GetService("ServerScriptService").Services.Data.DataService)
			local handle = DataService.GetHandle(player.UserId)
			if handle then
				DataService.Commit(handle, {
					operationId = "world2_admin_unlock_" .. player.UserId,
					fingerprint = "admin_unlock_w2",
					commands = { { kind = "SetPersistent", key = "World2Unlocked", value = true } }
				})
			end
			newlyUnlocked = true
		else
			local level = getLevel(player)
			local rebirths = math.max(0, math.floor(getLeaderstat(player, "Rebirths")))
			if rebirths < WORLD_2_REBIRTH_REQUIREMENT or level < WORLD_2_LEVEL_REQUIREMENT then
				local missing = {}
				if rebirths < WORLD_2_REBIRTH_REQUIREMENT then
					table.insert(missing, tostring(WORLD_2_REBIRTH_REQUIREMENT - rebirths) .. " more Rebirths")
				end
				if level < WORLD_2_LEVEL_REQUIREMENT then
					table.insert(missing, tostring(WORLD_2_LEVEL_REQUIREMENT - level) .. " more Levels")
				end
				sendState(player, "Need " .. table.concat(missing, " + "), false, "Locked")
				return
			end

			local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
			local handle=DataService.GetHandle(player.UserId)
			if not handle then sendState(player,"Data is not ready yet.",false,"Busy");return end
			local result=DataService.Commit(handle,{operationId="world2_unlock_"..player.UserId,fingerprint="unlock_w2",commands={{kind="SetPersistent",key="World2Unlocked",value=true}}})
			if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
				sendState(player,"Waiting for your unlock to save. Try again shortly.",false,"Busy");return
			end
			newlyUnlocked=true
		end
	end

	if destinationWorld == 3 and player:GetAttribute("World3Unlocked") ~= true then
		if isPlayerAdmin(player) then
			player:SetAttribute("World3Unlocked", true)
			local DataService = require(game:GetService("ServerScriptService").Services.Data.DataService)
			local handle = DataService.GetHandle(player.UserId)
			if handle then
				DataService.Commit(handle, {
					operationId = "world3_admin_unlock_" .. player.UserId,
					fingerprint = "admin_unlock_w3",
					commands = { { kind = "SetPersistent", key = "World3Unlocked", value = true } },
				})
			end
			newlyUnlocked = true
		else
			local level = getLevel(player)
			local rebirths = math.max(0, math.floor(getLeaderstat(player, "Rebirths")))
			if rebirths < WORLD_3_REBIRTH_REQUIREMENT or level < WORLD_3_LEVEL_REQUIREMENT then
				local missing = {}
				if rebirths < WORLD_3_REBIRTH_REQUIREMENT then
					table.insert(missing, tostring(WORLD_3_REBIRTH_REQUIREMENT - rebirths) .. " more Rebirths")
				end
				if level < WORLD_3_LEVEL_REQUIREMENT then
					table.insert(missing, tostring(WORLD_3_LEVEL_REQUIREMENT - level) .. " more Levels")
				end
				sendState(player, "Need " .. table.concat(missing, " + "), false, "Locked")
				return
			end
			local DataService = require(game:GetService("ServerScriptService").Services.Data.DataService)
			local handle = DataService.GetHandle(player.UserId)
			if not handle then
				sendState(player, "Data is not ready yet.", false, "Busy")
				return
			end
			local result = DataService.Commit(handle, {
				operationId = "world3_unlock_" .. player.UserId,
				fingerprint = "unlock_w3",
				commands = { { kind = "SetPersistent", key = "World3Unlocked", value = true } },
			})
			if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
				sendState(player, "Waiting for your unlock to save. Try again shortly.", false, "Busy")
				return
			end
			newlyUnlocked = true
		end
	end

	if newlyUnlocked then
		if destinationWorld == 3 then
			FunnelAnalytics.Step(player, "CoreLoop_Rebirths", 3)
		elseif destinationWorld == 2 then
			FunnelAnalytics.Step(player, "Onboarding_FTUE", 6)
			-- The newcomer ladder's last step (FunnelAnalytics skips everyone else).
			FunnelAnalytics.Step(player, "Onboarding_Ladder", 6)
		end
	end

	local targetPlaceId = nil
	if destinationWorld == 3 then
		targetPlaceId = resolveWorld3PlaceId()
		if not targetPlaceId or targetPlaceId <= 0 then
			sendState(player, "World 3 is coming soon", false, "ComingSoon")
			return
		end
	elseif destinationWorld == 2 then
		targetPlaceId = WORLD_2_PLACE_ID
	else
		targetPlaceId = resolveWorld1PlaceId()
	end
	if not targetPlaceId or targetPlaceId <= 0 then
		if destinationWorld == 1 then
			world1ResolutionFinished = false
		end
		sendState(player, world1ResolutionError or "World 1 is temporarily unavailable", false, "Error")
		return
	end

	if RunService:IsStudio() then
		local studioMessage = string.format(
			"Studio: Teleport to World %d ready (Place ID: %d). Test in Roblox app!",
			destinationWorld,
			targetPlaceId
		)
		sendState(player, studioMessage, false, "StudioPreview")
		return
	end

	teleporting[player] = {
		DestinationWorld = destinationWorld,
		PlaceId = targetPlaceId,
		StartedAt = os.clock(),
	}
	player:SetAttribute("CrossPlaceTeleporting", true)
	sendState(player, "Teleporting to World " .. tostring(destinationWorld) .. "...", false, "Teleporting")

	local saved, saveError = saveForTeleport(player)
	if not saved then
		failTeleport(player, "Teleport stopped: " .. tostring(saveError))
		return
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		FromWorld = currentWorld(),
		DestinationWorld = destinationWorld,
		PortalVersion = "V306JL",
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(targetPlaceId, { player }, teleportOptions)
	end)
	if not ok then
		local failedAttempt = teleporting[player]
		failTeleport(player, "Teleport failed: " .. tostring(err), failedAttempt)
		warn("[WorldPortalService] TeleportAsync failed for " .. player.Name .. ": " .. tostring(err))
		return
	end

	armTeleportTimeout(player, teleporting[player])
end
WorldPortalAction.OnServerEvent:Connect(function(player, action, destinationWorld)
 handlePortalAction(player, action, destinationWorld, false)
end)
_G.SpeedsterAdminWorldTravel = function(player, destinationWorld)
 handlePortalAction(player, "Travel", destinationWorld, true)
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
	local attempt = teleporting[player]
	if not attempt or tonumber(placeId) ~= attempt.PlaceId then
		return
	end

	local resultName = typeof(teleportResult) == "EnumItem" and teleportResult.Name or tostring(teleportResult)
	local detail = errorMessage
	if not detail or detail == "" then
		detail = resultName
	end
	failTeleport(player, "Teleport failed (" .. resultName .. "): " .. tostring(detail), attempt)
	warn(
		"[WorldPortalService] TeleportInitFailed for "
			.. player.Name
			.. " | result="
			.. tostring(teleportResult)
			.. " | "
			.. tostring(errorMessage)
	)
end)

----------------------------------------------------------------------
-- Auto-unlock (2026-09-20). The moment a player first meets the next world's requirements
-- the unlock is saved, with the same idempotent commit the portal makes. The flag never
-- turns off, so the client's unlock flight (UI/WorldPortalCinematic, which plays when the
-- flag turns on) can only ever play once per world, and a rebirth (level back to 1) no
-- longer locks a portal the game has just announced as open.
----------------------------------------------------------------------
local autoUnlockBusy = {}
local function tryAutoUnlock(player)
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or autoUnlockBusy[player] then
		return
	end
	local world = currentWorld()
	local key, needRebirths, needLevel, funnel, funnelStep
	if world == 1 and not WORLD_2_COMING_SOON then
		key, needRebirths, needLevel = "World2Unlocked", WORLD_2_REBIRTH_REQUIREMENT, WORLD_2_LEVEL_REQUIREMENT
		funnel, funnelStep = "Onboarding_FTUE", 6
	elseif world == 2 then
		key, needRebirths, needLevel = "World3Unlocked", WORLD_3_REBIRTH_REQUIREMENT, WORLD_3_LEVEL_REQUIREMENT
		funnel, funnelStep = "CoreLoop_Rebirths", 3
	else
		return
	end
	if player:GetAttribute(key) == true then
		return
	end
	local rebirths = math.max(0, math.floor(getLeaderstat(player, "Rebirths")))
	if rebirths < needRebirths or getLevel(player) < needLevel then
		return
	end
	autoUnlockBusy[player] = true
	local ok, problem = pcall(function()
		local DataService = require(game:GetService("ServerScriptService").Services.Data.DataService)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then
			-- A Studio preview without a save: show the unlock anyway.
			if RunService:IsStudio() then
				player:SetAttribute(key, true)
			end
			return
		end
		local result = DataService.Commit(handle, {
			operationId = string.lower(string.sub(key, 1, 6)) .. "_unlock_" .. player.UserId,
			fingerprint = "unlock_w" .. string.sub(key, 6, 6),
			commands = { { kind = "SetPersistent", key = key, value = true } },
		})
		if result.kind == "Committed" or result.kind == "AlreadyCommitted" then
			if player:GetAttribute(key) ~= true then
				player:SetAttribute(key, true)
			end
			FunnelAnalytics.Step(player, funnel, funnelStep)
			if key == "World2Unlocked" then
				-- The newcomer ladder's last step (FunnelAnalytics skips everyone else).
				FunnelAnalytics.Step(player, "Onboarding_Ladder", 6)
			end
		end
	end)
	if not ok then
		warn("[WorldPortalService] auto-unlock failed for " .. player.Name .. ": " .. tostring(problem))
	end
	-- A failed save is tried again on the next level or rebirth, not in a tight loop.
	task.delay(5, function()
		autoUnlockBusy[player] = nil
	end)
end

local function watchAutoUnlock(player)
	local function check()
		task.spawn(tryAutoUnlock, player)
	end
	player:GetAttributeChangedSignal("Level"):Connect(check)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		-- A few seconds in, so a client that has just joined sees the flag turn on.
		task.delay(4, check)
	end)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 30)
		local rebirths = leaderstats and leaderstats:WaitForChild("Rebirths", 30)
		if rebirths then
			rebirths.Changed:Connect(check)
		end
	end)
	if player:GetAttribute("DataLoaded") == true then
		task.delay(4, check)
	end
end
Players.PlayerAdded:Connect(watchAutoUnlock)
for _, existing in ipairs(Players:GetPlayers()) do
	task.spawn(watchAutoUnlock, existing)
end

Players.PlayerRemoving:Connect(function(player)
	autoUnlockBusy[player] = nil
	lastTouchAt[player] = nil
	lastActionAt[player] = nil
	lastPortalPart[player] = nil
	teleporting[player] = nil
end)

print(
	"[WorldPortalService] V306JL+W3 loaded | World 2 at " .. WORLD_2_REBIRTH_REQUIREMENT
		.. " Rebirths + Level " .. WORLD_2_LEVEL_REQUIREMENT .. " | World 3 at "
		.. WORLD_3_REBIRTH_REQUIREMENT .. " Rebirths + Level " .. WORLD_3_LEVEL_REQUIREMENT
		.. " | event-driven PortalWorld2 parts="
		.. tostring(portalPartCount)
		.. " | World1PlaceId="
		.. tostring(WORLD_1_PLACE_ID)
		.. " | World2PlaceId="
		.. tostring(WORLD_2_PLACE_ID)
		.. " | World3PlaceId="
		.. tostring(WORLD_3_PLACE_ID)
)
