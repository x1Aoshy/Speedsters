         
                                                    
                                                                       
                                                                               
                                                                    

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WORLD_1_PLACE_ID = 85065221510105
local WORLD_2_PLACE_ID = 116359653478954
local WORLD_2_COMING_SOON = false
local WORLD_2_REBIRTH_REQUIREMENT = 7
local WORLD_2_LEVEL_REQUIREMENT = 100
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
	if Config.IsWorld2Place then
		return 2
	end
	return (game.PlaceId == WORLD_2_PLACE_ID or game.PlaceId == 116359653478954) and 2 or 1
end

local function normalizedPlaceName(value)
	return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function resolveWorld1PlaceId()
	if world1ResolutionFinished then
		return world1PlaceId
	end

	if currentWorld() == 2 or game.PlaceId == WORLD_2_PLACE_ID or game.PlaceId == 116359653478954 then
		world1PlaceId = WORLD_1_PLACE_ID
		world1ResolutionFinished = true
		return world1PlaceId
	end

	if game.PlaceId > 0 and game.PlaceId ~= WORLD_2_PLACE_ID and game.PlaceId ~= 116359653478954 then
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
	return {
		CurrentWorld = currentWorld(),
		World2ComingSoon = WORLD_2_COMING_SOON,
		World2Unlocked = unlocked,
		Level = level,
		Rebirths = rebirths,
		RequiredLevel = WORLD_2_LEVEL_REQUIREMENT,
		RequiredRebirths = WORLD_2_REBIRTH_REQUIREMENT,
		MeetsWorld2Requirements = unlocked
			or (level >= WORLD_2_LEVEL_REQUIREMENT and rebirths >= WORLD_2_REBIRTH_REQUIREMENT),
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
	if currentWorld() == 2 and not world1ResolutionFinished then
		task.spawn(resolveWorld1PlaceId)
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
	-- World 1 is the starting world: players in World 2 are always permitted to return to World 1
	if destinationWorld == 1 and currentWorld() == 2 then
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

WorldPortalAction.OnServerEvent:Connect(function(player, action, destinationWorld)
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
	if destinationWorld ~= 1 and destinationWorld ~= 2 then
		return
	end
	if teleporting[player] then
		sendState(player, "Teleport already starting...", false, "Busy")
		return
	end
	if not isPlayerAllowedToTravel(player, destinationWorld) then
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
	if destinationWorld == 2 and player:GetAttribute("World2Unlocked") ~= true then
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

	local targetPlaceId = nil
	if destinationWorld == 2 then
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
end)

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

Players.PlayerRemoving:Connect(function(player)
	lastTouchAt[player] = nil
	lastActionAt[player] = nil
	lastPortalPart[player] = nil
	teleporting[player] = nil
end)

print(
	"[WorldPortalService] V306JL loaded | World 2 enabled at 7 Rebirths + Level 100 | event-driven PortalWorld2 parts="
		.. tostring(portalPartCount)
		.. " | World2PlaceId="
		.. tostring(WORLD_2_PLACE_ID)
)
