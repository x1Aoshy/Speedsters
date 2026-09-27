--!strict
-- GiftedPasses.luau
-- Game passes received as gifts. A gift is a developer product (Config.GamePassGiftProducts)
-- whose receipt saves "GiftedPass:<passId>" in the recipient's OwnedUpgrades, in the same
-- transaction as the receipt. Everything that asks "does this player own the pass?"
-- accepts that saved gift as well as Roblox's own ownership record.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GiftedPasses = {}

GiftedPasses.Prefix = "GiftedPass:"

-- Passes whose perk already lives in the profile under its own upgrade id: the gift
-- grants that upgrade too, so the existing projection unlocks it with no extra code.
local PROFILE_UPGRADES = {
	[tonumber(Config.AbilityFlightGamePassId) or 0] = "Flight",
	[tonumber(Config.DoubleWinsPadGamePassId) or 0] = "TwoXVictory",
}

local dataService = nil
local function getDataService()
	if dataService == nil then
		local ok, module = pcall(function()
			return require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
		end)
		dataService = if ok then module else false
	end
	return dataService or nil
end

function GiftedPasses.UpgradeId(passId: number): string
	return GiftedPasses.Prefix .. tostring(math.floor(passId))
end

-- The gift entry for a pass, or for a gift product id.
function GiftedPasses.EntryForPass(passId: number)
	for _, entry in Config.GamePassGiftProducts or {} do
		if tonumber(entry.PassId) == passId then
			return entry
		end
	end
	return nil
end

function GiftedPasses.EntryForProduct(productId: number)
	for _, entry in Config.GamePassGiftProducts or {} do
		local id = tonumber(entry.ProductId)
		if id and id > 0 and id == productId then
			return entry
		end
	end
	return nil
end

-- The profile commands a gift of `passId` writes on the recipient.
function GiftedPasses.Commands(passId: number): { any }
	local commands = { { kind = "GrantUpgrade", upgradeId = GiftedPasses.UpgradeId(passId) } }
	local upgrade = PROFILE_UPGRADES[passId]
	if upgrade then
		table.insert(commands, { kind = "GrantUpgrade", upgradeId = upgrade })
	end
	-- 2026-09-21: the 2x Speed perk lives in the permanent Speed multiplier, which used to be
	-- set only as an attribute and was repainted from the profile within a second. It is saved
	-- with the receipt now; PurchaseMultiplier only raises, so a bought x4..x32 rung stays.
	local twoXSpeedId = tonumber(Config.TwoXSpeedGamePassId)
	if twoXSpeedId and twoXSpeedId > 0 and passId == twoXSpeedId then
		table.insert(commands, { kind = "PurchaseMultiplier", key = "PermanentBaseSpeedMultiplier", target = 2 })
	end
	return commands
end

local function ownedUpgrades(player: Player): { string }?
	if player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	local DataService = getDataService()
	local handle = DataService and DataService.GetHandle(player.UserId)
	if not handle then
		return nil
	end
	local view = DataService.Inspect(handle)
	if not view.ok or not view.value.profile then
		return nil
	end
	return view.value.profile.OwnedUpgrades or {}
end

-- True when the player's loaded profile holds a gift of this pass.
function GiftedPasses.Has(player: Player, passId: number): boolean
	local upgrades = ownedUpgrades(player)
	return upgrades ~= nil and table.find(upgrades, GiftedPasses.UpgradeId(passId)) ~= nil
end

-- Every gifted pass id in the player's loaded profile.
function GiftedPasses.List(player: Player): { number }
	local list = {}
	for _, upgrade in ownedUpgrades(player) or {} do
		if string.sub(upgrade, 1, #GiftedPasses.Prefix) == GiftedPasses.Prefix then
			local passId = tonumber(string.sub(upgrade, #GiftedPasses.Prefix + 1))
			if passId then
				table.insert(list, passId)
			end
		end
	end
	return list
end

return GiftedPasses
