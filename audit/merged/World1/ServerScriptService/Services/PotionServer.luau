--[[
	PotionServer — temporary 2x Speed / 2x Wins potions and the server-wide Speed Boost.

	Potions are per-player and persist their REMAINING time across sessions:
	the ExpireUnix attribute is only authoritative while the player is online, and
	PlayerStats saves remaining seconds (expire - os.time()) so offline time is skipped.

	The server boost is server-session only: it ends when the server ends, and
	players who leave lose the remaining boost (per design).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TemporaryBoostUpdate = Remotes:FindFirstChild("TemporaryBoostUpdate")
if not TemporaryBoostUpdate then
	TemporaryBoostUpdate = Instance.new("RemoteEvent")
	TemporaryBoostUpdate.Name = "TemporaryBoostUpdate"
	TemporaryBoostUpdate.Parent = Remotes
end

local PotionServer = {}

local function cleanNonNegative(value)
	value = tonumber(value) or 0
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return value
end

-- Server-session server boost (does not survive server restarts)
local initialWsExpire = cleanNonNegative(Workspace:GetAttribute("ServerBoostExpiresUnix"))
local initialWsMult = tonumber(Workspace:GetAttribute("ServerBoostMultiplier")) or 1
local serverBoostExpiresUnix = initialWsExpire
local serverBoostMultiplier = initialWsMult
if Workspace:GetAttribute("ServerBoostExpiresUnix") == nil then
	Workspace:SetAttribute("ServerBoostExpiresUnix", 0)
end
if Workspace:GetAttribute("ServerBoostMultiplier") == nil then
	Workspace:SetAttribute("ServerBoostMultiplier", 1)
end

local function now()
	return os.time()
end

local function fireBoost(player, payload)
	if player and player.Parent == Players then
		pcall(function()
			TemporaryBoostUpdate:FireClient(player, payload)
		end)
	end
end

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds >= 3600 and seconds % 3600 == 0 then
		local hours = seconds / 3600
		return tostring(hours) .. (hours == 1 and " hour" or " hours")
	end
	if seconds >= 60 then
		local minutes = math.floor(seconds / 60)
		return tostring(minutes) .. (minutes == 1 and " minute" or " minutes")
	end
	return tostring(seconds) .. (seconds == 1 and " second" or " seconds")
end

local function makeDurationText(minutes)
	minutes = math.max(1, math.floor(tonumber(minutes) or 10))
	if minutes >= 60 and minutes % 60 == 0 then
		local hours = minutes / 60
		return tostring(hours) .. (hours == 1 and " hour" or " hours")
	end
	return tostring(minutes) .. (minutes == 1 and " minute" or " minutes")
end

local function grantPotion(player, expireAttribute, multiplierAttribute, bottleAttribute, durationMinutes, multiplier, configMultiplier, bottleType)
	if not player or player.Parent ~= Players then
		return nil
	end
	local duration = math.max(1, math.floor(tonumber(durationMinutes) or 10)) * 60
	local mult = math.max(1, tonumber(multiplier) or configMultiplier or 2)
	local currentExpire = cleanNonNegative(player:GetAttribute(expireAttribute))
	local baseTime = math.max(currentExpire, now())
	local newExpire = baseTime + duration
	player:SetAttribute(expireAttribute, newExpire)
	player:SetAttribute(multiplierAttribute, mult)
	if bottleAttribute and bottleType then
		player:SetAttribute(bottleAttribute, tostring(bottleType))
	end
	return newExpire
end

function PotionServer.GrantSpeedPotion(player, durationMinutes, multiplier, bottleType, operationId)
	if not player or player.Parent ~= Players then
		return nil
	end
	local mins = math.max(1, math.floor(tonumber(durationMinutes) or 10))
	local mult = math.max(1, tonumber(multiplier) or Config.PotionSpeedMultiplier or 2)
	local duration = mins * 60
	local bType = tostring(bottleType or "Small")

	-- If DataService is active, commit to persistent profile so offline pause/resume and cross-server persistence work
	local hasDataService, DataService = pcall(function()
		return require(script.Parent.Data.DataService)
	end)
	local handle = hasDataService and DataService and DataService.GetHandle(player.UserId)
	if handle then
		local id = operationId or DataService.NewOperationId()
		local result = DataService.Commit(handle, {
			operationId = id,
			fingerprint = "potion-speed:" .. duration .. ":" .. mult .. ":" .. bType,
			commands = {
				{
					kind = "GrantBuff",
					grant = {
						kind = "SpeedPotion",
						addedSeconds = duration,
						multiplier = mult,
						bottleType = bType,
					},
				},
			},
		})
		if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
			return nil
		end
		local expire = cleanNonNegative(player:GetAttribute("PotionSpeedExpireUnix"))
		local function notify()
			fireBoost(player, {
				Type = "SpeedPotion",
				Message = tostring(mult) .. "x Speed Potion active for " .. makeDurationText(mins) .. "!",
				RemainingSeconds = math.max(0, expire - now()),
			})
		end
		notify()
		return {
			ExpireUnix = expire,
			Notify = notify,
			Rollback = function() end,
		}
	end

	-- Fallback for tests or offline contexts without DataService handle:
	local previous = cleanNonNegative(player:GetAttribute("PotionSpeedExpireUnix"))
	local previousBottle = player:GetAttribute("PotionSpeedBottle")
	local newExpire = grantPotion(
		player,
		"PotionSpeedExpireUnix",
		"PotionSpeedMultiplier",
		"PotionSpeedBottle",
		durationMinutes,
		multiplier,
		Config.PotionSpeedMultiplier,
		bType
	)
	if not newExpire then
		return nil
	end
	return {
		ExpireUnix = newExpire,
		Rollback = function()
			player:SetAttribute("PotionSpeedExpireUnix", previous)
			if previousBottle ~= nil then
				player:SetAttribute("PotionSpeedBottle", previousBottle)
			end
		end,
		Notify = function()
			fireBoost(player, {
				Type = "SpeedPotion",
				Message = tostring(mult) .. "x Speed Potion active for " .. makeDurationText(mins) .. "!",
				RemainingSeconds = newExpire - now(),
			})
		end,
	}
end

function PotionServer.GrantWinsPotion(player, durationMinutes, multiplier, bottleType, operationId)
	if not player or player.Parent ~= Players then
		return nil
	end
	local mins = math.max(1, math.floor(tonumber(durationMinutes) or 10))
	local mult = math.max(1, tonumber(multiplier) or Config.PotionWinsMultiplier or 2)
	local duration = mins * 60
	local bType = tostring(bottleType or "Small")

	-- If DataService is active, commit to persistent profile so offline pause/resume and cross-server persistence work
	local hasDataService, DataService = pcall(function()
		return require(script.Parent.Data.DataService)
	end)
	local handle = hasDataService and DataService and DataService.GetHandle(player.UserId)
	if handle then
		local id = operationId or DataService.NewOperationId()
		local result = DataService.Commit(handle, {
			operationId = id,
			fingerprint = "potion-wins:" .. duration .. ":" .. mult .. ":" .. bType,
			commands = {
				{
					kind = "GrantBuff",
					grant = {
						kind = "WinsPotion",
						addedSeconds = duration,
						multiplier = mult,
						bottleType = bType,
					},
				},
			},
		})
		if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
			return nil
		end
		local expire = cleanNonNegative(player:GetAttribute("PotionWinsExpireUnix"))
		local function notify()
			fireBoost(player, {
				Type = "WinsPotion",
				Message = tostring(mult) .. "x Wins Potion active for " .. makeDurationText(mins) .. "!",
				RemainingSeconds = math.max(0, expire - now()),
			})
		end
		notify()
		return {
			ExpireUnix = expire,
			Notify = notify,
			Rollback = function() end,
		}
	end

	-- Fallback for tests or offline contexts without DataService handle:
	local previous = cleanNonNegative(player:GetAttribute("PotionWinsExpireUnix"))
	local previousBottle = player:GetAttribute("PotionWinsBottle")
	local newExpire = grantPotion(
		player,
		"PotionWinsExpireUnix",
		"PotionWinsMultiplier",
		"PotionWinsBottle",
		durationMinutes,
		multiplier,
		Config.PotionWinsMultiplier,
		bType
	)
	if not newExpire then
		return nil
	end
	return {
		ExpireUnix = newExpire,
		Rollback = function()
			player:SetAttribute("PotionWinsExpireUnix", previous)
			if previousBottle ~= nil then
				player:SetAttribute("PotionWinsBottle", previousBottle)
			end
		end,
		Notify = function()
			fireBoost(player, {
				Type = "WinsPotion",
				Message = tostring(mult) .. "x Wins Potion active for " .. makeDurationText(mins) .. "!",
				RemainingSeconds = newExpire - now(),
			})
		end,
	}
end

function PotionServer.GrantServerBoost(durationMinutes, multiplier, buyerName)
	local duration = math.max(1, math.floor(tonumber(durationMinutes) or 30)) * 60
	local mult = math.max(1, tonumber(multiplier)
		or (Config.ServerSpeedBoostProduct and Config.ServerSpeedBoostProduct.TargetMultiplier)
		or 2)
	local currentWsExpire = cleanNonNegative(Workspace:GetAttribute("ServerBoostExpiresUnix"))
	local effectivePreviousExpire = math.max(serverBoostExpiresUnix, currentWsExpire)
	local previousMultiplier = math.max(serverBoostMultiplier, tonumber(Workspace:GetAttribute("ServerBoostMultiplier")) or 1)
	local wasActive = now() < effectivePreviousExpire
	local newExpire = (wasActive and effectivePreviousExpire or now()) + duration
	serverBoostMultiplier = mult
	serverBoostExpiresUnix = newExpire
	Workspace:SetAttribute("ServerBoostExpiresUnix", newExpire)
	Workspace:SetAttribute("ServerBoostMultiplier", mult)
	return {
		ExpireUnix = newExpire,
		Rollback = function()
			serverBoostExpiresUnix = effectivePreviousExpire
			serverBoostMultiplier = previousMultiplier
			Workspace:SetAttribute("ServerBoostExpiresUnix", effectivePreviousExpire)
			Workspace:SetAttribute("ServerBoostMultiplier", previousMultiplier)
		end,
		Notify = function()
			local minutes = math.max(1, math.floor(tonumber(durationMinutes) or 30))
			local prefix = ""
			if type(buyerName) == "string" and buyerName ~= "" then
				prefix = "🚀 " .. buyerName .. " activated "
			else
				prefix = "🚀 "
			end
			local msg = prefix .. tostring(mult) .. "x Speed for the server! (" .. makeDurationText(minutes) .. ")"
			for _, player in ipairs(Players:GetPlayers()) do
				fireBoost(player, {
					Type = "ServerBoost",
					Message = msg,
					RemainingSeconds = newExpire - now(),
					ServerBoost = true,
					BuyerName = buyerName,
				})
			end
		end,
	}
end

function PotionServer.GetServerBoostMultiplier()
	local expire = math.max(serverBoostExpiresUnix, cleanNonNegative(Workspace:GetAttribute("ServerBoostExpiresUnix")))
	if now() < expire then
		local mult = math.max(serverBoostMultiplier, tonumber(Workspace:GetAttribute("ServerBoostMultiplier")) or 1)
		return mult
	end
	return 1
end

function PotionServer.IsServerBoostActive()
	local expire = math.max(serverBoostExpiresUnix, cleanNonNegative(Workspace:GetAttribute("ServerBoostExpiresUnix")))
	return now() < expire
end

function PotionServer.RemainingServerBoostSeconds()
	local expire = math.max(serverBoostExpiresUnix, cleanNonNegative(Workspace:GetAttribute("ServerBoostExpiresUnix")))
	return math.max(0, expire - now())
end

function PotionServer.GetSpeedPotionMultiplier(player)
	if not player then
		return 1
	end
	if now() < cleanNonNegative(player:GetAttribute("PotionSpeedExpireUnix")) then
		return math.max(1, tonumber(player:GetAttribute("PotionSpeedMultiplier")) or Config.PotionSpeedMultiplier or 2)
	end
	return 1
end

function PotionServer.GetWinsPotionMultiplier(player)
	if not player then
		return 1
	end
	if now() < cleanNonNegative(player:GetAttribute("PotionWinsExpireUnix")) then
		return math.max(1, tonumber(player:GetAttribute("PotionWinsMultiplier")) or Config.PotionWinsMultiplier or 2)
	end
	return 1
end

function PotionServer.GetRemainingSpeedPotionSeconds(player)
	return math.max(0, cleanNonNegative(player and player:GetAttribute("PotionSpeedExpireUnix")) - now())
end

function PotionServer.GetRemainingWinsPotionSeconds(player)
	return math.max(0, cleanNonNegative(player and player:GetAttribute("PotionWinsExpireUnix")) - now())
end

function PotionServer.GrantTemporaryFlight(player,durationMinutes,granterName,operationId)
	if not player or player.Parent~=Players then return nil end
	local mins=tonumber(durationMinutes) or 20
	if mins~=mins or math.abs(mins)==math.huge or mins<=0 then return nil end
	local DataService=require(script.Parent.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then return nil end
	local duration=math.min(86400*30,math.floor(mins*60))
	local id=operationId or DataService.NewOperationId()
	local result=DataService.Commit(handle,{operationId=id,fingerprint="temporary-flight:"..duration,commands={{kind="GrantBuff",grant={kind="TemporaryFlight",addedSeconds=duration}}}})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then return nil end
	local expire=cleanNonNegative(player:GetAttribute("TemporaryFlightExpireUnix"))
	local message="Flight active for "..makeDurationText(mins).."!"
	local function notify()
		fireBoost(player,{Type="TemporaryFlight",Message=message,RemainingSeconds=math.max(0,expire-now())})
	end
	notify()
	return {ExpireUnix=expire,Notify=notify}
end

function PotionServer.GetRemainingTemporaryFlightSeconds(player)
	return math.max(0, cleanNonNegative(player and player:GetAttribute("TemporaryFlightExpireUnix")) - now())
end

function PotionServer.AnnounceActiveBoosts(player)
	task.delay(1.5, function()
		if player.Parent ~= Players then
			return
		end
		local speedSeconds = PotionServer.GetRemainingSpeedPotionSeconds(player)
		if speedSeconds > 0 then
			fireBoost(player, {
				Type = "SpeedPotion",
				Message = "2x Speed Potion is still active with " .. formatRemaining(speedSeconds) .. " remaining!",
				RemainingSeconds = speedSeconds,
			})
		end
		local winsSeconds = PotionServer.GetRemainingWinsPotionSeconds(player)
		if winsSeconds > 0 then
			fireBoost(player, {
				Type = "WinsPotion",
				Message = "2x Wins Potion is still active with " .. formatRemaining(winsSeconds) .. " remaining!",
				RemainingSeconds = winsSeconds,
			})
		end
		local flightSeconds = PotionServer.GetRemainingTemporaryFlightSeconds(player)
		if flightSeconds > 0 then
			fireBoost(player, {
				Type = "TemporaryFlight",
				Message = "✈️ Flight is still active with " .. formatRemaining(flightSeconds) .. " remaining!",
				RemainingSeconds = flightSeconds,
			})
		end
		local boostSeconds = PotionServer.RemainingServerBoostSeconds()
		if boostSeconds > 0 then
			fireBoost(player, {
				Type = "ServerBoost",
				Message = "Server-wide 2x Speed boost is active with " .. formatRemaining(boostSeconds) .. " remaining!",
				RemainingSeconds = boostSeconds,
			})
		end
	end)
end

return PotionServer
