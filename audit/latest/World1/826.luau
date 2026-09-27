local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local VIP_PASS_ID = Config.VipGamePassId or 0
local VIP_TEST_IDS = Config.VipTestUserIds or {}
local VIP_SPEED_MULT = Config.VipSpeedGainMultiplier or 2
local VIP_WINS_MULT = Config.VipWinsMultiplier or 2

local function isTestUser(userId)
	for _, id in ipairs(VIP_TEST_IDS) do
		if id == userId then return true end
	end
	return false
end

local function grantVip(player)
	player:SetAttribute("VIPGamepassOwned", true)
	player:SetAttribute("VIPSpeedGainMultiplier", VIP_SPEED_MULT)
	player:SetAttribute("VIPWinsMultiplier", VIP_WINS_MULT)
	if _G.SpeedsterApplyWalkSpeed then
		pcall(function() _G.SpeedsterApplyWalkSpeed(player) end)
	end
end

local function removeVip(player)
	player:SetAttribute("VIPGamepassOwned", false)
	player:SetAttribute("VIPSpeedGainMultiplier", 1)
	player:SetAttribute("VIPWinsMultiplier", 1)
	if _G.SpeedsterApplyWalkSpeed then
		pcall(function() _G.SpeedsterApplyWalkSpeed(player) end)
	end
end

local function checkAndGrant(player)
	if isTestUser(player.UserId) then
		grantVip(player)
		return
	end
	if VIP_PASS_ID <= 0 then return end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
	end)
	if ok and owns then
		grantVip(player)
	else
		removeVip(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	while player.Parent and player:GetAttribute("DataLoaded") ~= true do
		task.wait(0.1)
	end
	if player.Parent then
		checkAndGrant(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		while player.Parent and player:GetAttribute("DataLoaded") ~= true do
			task.wait(0.1)
		end
		if player.Parent then
			checkAndGrant(player)
		end
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if gamePassId == VIP_PASS_ID and wasPurchased then
		checkAndGrant(player)
	end
end)

_G.SpeedsterRefreshVip = function(player)
	if player and player.Parent then
		checkAndGrant(player)
	end
end