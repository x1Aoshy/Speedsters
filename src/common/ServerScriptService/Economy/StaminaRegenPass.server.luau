-- StaminaRegenPass.server.luau (Update 4, 2026-09-25)
-- The 2x Stamina Regen gamepass: who owns it. This script only sets the player attribute
-- StaminaRegen2xOwned; Bootstrap's stamina loop reads it (regen x2, regen delay x0.5, outside
-- races only) together with U4.IsOn("StaminaPass").
--
-- Owned = Roblox's ownership record (UserOwnsGamePassAsync, 3 tries) or a gift saved on the
-- profile (GiftedPasses, "GiftedPass:<passId>", like every other pass), checked once the data
-- has loaded; a purchase in this session sets it at once and logs the funnel's Purchased step;
-- a gift received while playing is seen when its upgrade appears in SpeedsterData.OwnedUpgrades.
-- Nothing here runs while the pass is off: U4.StaminaPass.GamePassId is 0 until the owner
-- creates the pass (U4.IsOn is false then), and the Workspace kill switch U4Off_StaminaPass.
-- The admin panel's pass toggle sets the same attribute for the session.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local U4 = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Update4Config"))
local Services = ServerScriptService:WaitForChild("Services")
local GiftedPasses = require(Services:WaitForChild("Monetization"):WaitForChild("GiftedPasses"))
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

local ATTRIBUTE = "StaminaRegen2xOwned"
local OWNERSHIP_TRIES = 3

local function passId(): number
	local id = tonumber(U4.StaminaPass.GamePassId) or 0
	return if id > 0 then math.floor(id) else 0
end

local function active(): boolean
	return U4.IsOn("StaminaPass") and passId() > 0
end

local function waitForData(player: Player, seconds: number): boolean
	local deadline = os.clock() + seconds
	while player.Parent == Players and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
		task.wait(0.25)
	end
	return player.Parent == Players and player:GetAttribute("DataLoaded") == true
end

-- Roblox's record: true / false, or nil when every try failed (then nothing is changed).
local function ownsOnRoblox(player: Player, id: number): boolean?
	for attempt = 1, OWNERSHIP_TRIES do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok then
			return owns == true
		end
		if attempt < OWNERSHIP_TRIES and player.Parent == Players then
			task.wait(attempt * 2)
		end
	end
	return nil
end

local function refresh(player: Player)
	if not active() or not waitForData(player, 60) then
		return
	end
	local id = passId()
	if GiftedPasses.Has(player, id) or ownsOnRoblox(player, id) == true then
		if player.Parent == Players then
			player:SetAttribute(ATTRIBUTE, true)
		end
	end
end

-- A gift arriving mid-session writes "GiftedPass:<id>" into the profile, which the projection
-- mirrors into SpeedsterData.OwnedUpgrades.
local function watchGifts(player: Player)
	local data = player:WaitForChild("SpeedsterData", 60)
	local owned = data and data:WaitForChild("OwnedUpgrades", 30)
	if not owned then
		return
	end
	owned.ChildAdded:Connect(function(child)
		local id = passId()
		if id > 0 and active() and child.Name == GiftedPasses.UpgradeId(id) then
			player:SetAttribute(ATTRIBUTE, true)
		end
	end)
end

local function onPlayerAdded(player: Player)
	if passId() <= 0 then
		return
	end
	task.spawn(refresh, player)
	task.spawn(watchGifts, player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, purchasedPassId: number, wasPurchased: boolean)
	if wasPurchased ~= true or not active() then
		return
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return
	end
	if tonumber(purchasedPassId) ~= passId() then
		return
	end
	player:SetAttribute(ATTRIBUTE, true)
	FunnelAnalytics.Step(player, "Monetization_StaminaPass", 3)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- For the admin panel and gifts: re-read ownership now.
_G.SpeedsterRefreshStaminaPass = function(player: Player)
	if typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players then
		task.spawn(refresh, player)
	end
end
