--!strict
-- src/ServerScriptService/Progression/PlayerStatsBridge.luau
-- Lote R1-10 / Reto 1: Fachada temporal de compatibilidad que exporta las 23 funciones de _G.Speedster...
-- Mapea exactamente cada llamada a los nuevos servicios desacoplados.

local DataService
local StatsService
local BuffService
local MonetizationService
local StatsProjection
local CharacterStatsAdapter
local ReceiptLedger
local inRoblox = typeof(script) == "Instance"
local RunService = if inRoblox then game:GetService("RunService") else nil
local Config = if inRoblox then require(game:GetService("ReplicatedStorage").Shared.Config) else {}
local PotionServer = if inRoblox then require(script.Parent.Parent.Services.PotionServer) else nil

local function attribute(player: any, key: string): number
	local value = player:GetAttribute(key)
	return if type(value) == "number" and value == value and math.abs(value) ~= math.huge and value >= 0 then value else 1
end

if typeof(script) == "Instance" and script.Parent then
	DataService = require(script.Parent.Parent.Services.Data.DataService)
	StatsService = require(script.Parent.Parent.Services.Stats.StatsService)
	BuffService = require(script.Parent.Parent.Services.Buffs.BuffService)
	MonetizationService = require(script.Parent.Parent.Services.Monetization.MonetizationService)
	StatsProjection = require(script.Parent.Parent.Services.Stats.StatsProjection)
	CharacterStatsAdapter = require(script.Parent.Parent.Services.Stats.CharacterStatsAdapter)
	ReceiptLedger = require(script.Parent.Parent.Services.Monetization.ReceiptLedger)
else
	DataService = require("../Services/Data/DataService")
	StatsService = require("../Services/Stats/StatsService")
	BuffService = require("../Services/Buffs/BuffService")
	MonetizationService = require("../Services/Monetization/MonetizationService")
	StatsProjection = require("../Services/Stats/StatsProjection")
	CharacterStatsAdapter = require("../Services/Stats/CharacterStatsAdapter")
	ReceiptLedger = require("../Services/Monetization/ReceiptLedger")
end

local PlayerStatsBridge = {}

-- Registra las 23 exportaciones globales canónicas en _G
function PlayerStatsBridge.RegisterGlobals()
	local g = (_G :: any)

	-- 1. SpeedsterAddSpeed
	g.SpeedsterAddSpeed = function(player: any, baseAmount: number, popupData: any?): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local before = DataService.Inspect(handle)
		local res = DataService.AccrueSpeed(handle, baseAmount, "Running", {
			permanent = attribute(player, "PermanentBaseSpeedMultiplier"),
			global = attribute(player, "GlobalSpeedGainMultiplier"),
			trail = attribute(player, "TrailSpeedGainMultiplier"),
			aura = attribute(player, "AuraSpeedGainMultiplier"),
			upgrade = attribute(player, "UpgradeSpeedGainMultiplier"),
			gamepass = attribute(player, "GamepassSpeedGainMultiplier"),
			suit = g.SpeedsterGetSuitSpeedGainMultiplierForSkin(player:GetAttribute("EquippedSkin")),
			rebirth = g.SpeedsterGetRebirthSpeedGainMultiplier(player:GetAttribute("Rebirths") or 0),
			vip = attribute(player, "VIPSpeedGainMultiplier"),
			potion = PotionServer and PotionServer.GetSpeedPotionMultiplier(player) or 1,
			serverBoost = PotionServer and PotionServer.GetServerBoostMultiplier() or 1,
		})
		if res.ok and popupData and inRoblox then
			local after = DataService.Inspect(handle)
			if before.ok and after.ok then
				local amount = after.value.profile.Speed - before.value.profile.Speed
				if amount > 0 or popupData.ForcePopup then
					local payload = table.clone(popupData)
					payload.Amount = amount > 0 and amount or (popupData.VisualAmount or baseAmount)
					payload.TotalSpeed = after.value.profile.Speed
					game:GetService("ReplicatedStorage").Remotes.SpeedGainPopup:FireClient(player, payload)
				end
			end
		end
		return res.ok
	end

	-- 2. SpeedsterApplyWalkSpeed
	g.SpeedsterApplyWalkSpeed = function(player: any)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		local inspectRes = DataService.Inspect(handle)
		if inspectRes.ok and inspectRes.value.profile then
			CharacterStatsAdapter.Update(player, inspectRes.value.profile.Speed or 0)
		end
	end

	-- 3. SpeedsterGetTotalGainMultiplier
	g.SpeedsterGetTotalGainMultiplier = function(player: any): number
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return 1.0 end
		local inspectRes = DataService.Inspect(handle)
		if not inspectRes.ok or not inspectRes.value.profile then return 1.0 end
		local p = inspectRes.value.profile
		local mult = (p.GlobalSpeedGainMultiplier or 1)
			* (p.TrailSpeedGainMultiplier or 1)
			* (attribute(player, "AuraSpeedGainMultiplier") or p.AuraSpeedGainMultiplier or 1)
			* (p.UpgradeSpeedGainMultiplier or 1)
			* (p.GamepassSpeedGainMultiplier or 1)
			* (math.max(attribute(player, "PermanentBaseSpeedMultiplier"), p.PermanentBaseSpeedMultiplier or 1))
		return mult
	end

	-- 4. SpeedsterGetSuitSpeedGainMultiplierForSkin
	g.SpeedsterGetSuitSpeedGainMultiplierForSkin = function(skinId: string): number
		local multipliers = Config.SuitSpeedGainMultipliers or {}
		return multipliers[skinId] or Config.DefaultSuitSpeedGainMultiplier or 1
	end

	-- 5. SpeedsterGetPermanentBaseSpeedMultiplier
	g.SpeedsterGetPermanentBaseSpeedMultiplier = function(player: any): number
		local attr = attribute(player, "PermanentBaseSpeedMultiplier")
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return attr end
		local inspect = DataService.Inspect(handle)
		local prof = (inspect.ok and inspect.value.profile and inspect.value.profile.PermanentBaseSpeedMultiplier) or 1.0
		return math.max(attr, prof)
	end

	-- 6. SpeedsterGetPermanentWinsMultiplier
	g.SpeedsterGetPermanentWinsMultiplier = function(player: any): number
		local attr = attribute(player, "PermanentWinsMultiplier")
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return attr end
		local inspect = DataService.Inspect(handle)
		local prof = (inspect.ok and inspect.value.profile and inspect.value.profile.PermanentWinsMultiplier) or 1.0
		return math.max(attr, prof)
	end

	g.SpeedsterSetPermanentBaseSpeedMultiplier = function(player: any, multiplier: number)
		player:SetAttribute("PermanentBaseSpeedMultiplier", multiplier)
		local handle = DataService.GetHandle(player.UserId)
		if handle then
			DataService.Commit(handle, {
				operationId = "perm_speed_mult_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
				fingerprint = "speed_mult_" .. tostring(multiplier),
				commands = {
					{ kind = "SetPersistent", key = "PermanentBaseSpeedMultiplier", value = multiplier }
				}
			})
		end
	end

	g.SpeedsterSetPermanentWinsMultiplier = function(player: any, multiplier: number)
		player:SetAttribute("PermanentWinsMultiplier", multiplier)
		local handle = DataService.GetHandle(player.UserId)
		if handle then
			DataService.Commit(handle, {
				operationId = "perm_wins_mult_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
				fingerprint = "wins_mult_" .. tostring(multiplier),
				commands = {
					{ kind = "SetPersistent", key = "PermanentWinsMultiplier", value = multiplier }
				}
			})
		end
	end

	-- 7. SpeedsterSyncSuitSpeedGainMultiplier
	g.SpeedsterSyncSuitSpeedGainMultiplier = function(player: any)
		local multiplier = g.SpeedsterGetSuitSpeedGainMultiplierForSkin(player:GetAttribute("EquippedSkin"))
		player:SetAttribute("SuitSpeedGainMultiplier", multiplier)
		player:SetAttribute("SkinSpeedGainMultiplier", multiplier)
	end

	-- 8. SpeedsterSavePlayer
	g.SpeedsterSavePlayer = function(player: any, reason: string?, waitForCompletion: boolean?): boolean
		if RunService and RunService:IsStudio() then
			local handle = DataService.GetHandle(player.UserId)
			if handle then
				DataService.Flush(handle)
			end
			return true
		end
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local flushRes = DataService.Flush(handle)
		return flushRes.kind == "Saved" or (flushRes.kind == "Skipped" and flushRes.reason == "Clean")
	end

	-- 8b. SpeedsterSetDailyLoginState
	g.SpeedsterSetDailyLoginState = function(player: any, dailyState: any): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local res = DataService.SetDailyLoginState(handle, dailyState)
		return res.ok == true
	end

	-- 9. SpeedsterAddWins
	g.SpeedsterAddWins = function(player: any, baseGain: number): boolean
		local handle = DataService and DataService.GetHandle(player.UserId)
		if not handle then return false end
		-- Preserve OG reward semantics: permanent wins bonuses apply to rewards.
		-- Exact purchased grants continue to use SpeedsterGrantExactStat.
		local amount = tonumber(baseGain) or 0
		if amount > 0 then amount *= g.SpeedsterGetPermanentWinsMultiplier(player) end
		local commitRes = DataService.Commit(handle, {
			operationId = string.format("wins_%d_%d_%d", player.UserId, os.time(), math.random(100, 999)),
			fingerprint = "add_wins",
			commands = {
				{ kind = "GrantExact", stat = "Wins", amount = amount },
			},
		})
		return commitRes ~= nil and (commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted")
	end

	-- 9b. SpeedsterSpendWins
	g.SpeedsterSpendWins = function(player: any, amount: number): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local commitRes = DataService.Commit(handle, {
			operationId = string.format("debit_wins_%d_%d_%d", player.UserId, os.time(), math.random(100, 999)),
			fingerprint = string.format("debit_wins_%d", amount),
			commands = {
				{ kind = "DebitWins", amount = amount },
			},
		})
		if commitRes and (commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted") then
			return true
		end
		return false
	end

	-- 10. SpeedsterGrantExactStat: Retorna (true, delta) o (false, errorReason)
	g.SpeedsterGrantExactStat = function(player: any, statName: string, amount: number): (boolean, any)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then
			return false, "No active session"
		end

		if statName ~= "Speed" and statName ~= "Wins" then
			return false, "Invalid stat name"
		end

		local commitRes = DataService.Commit(handle, {
			operationId = string.format("exact_%d_%s_%d", player.UserId, statName, os.time()),
			fingerprint = string.format("exact_%s_%d", statName, amount),
			commands = {
				{ kind = "GrantExact", stat = statName :: any, amount = amount },
			},
		})

		if commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted" then
			return true, amount
		else
			return false, "Commit rejected"
		end
	end

	-- 11. SpeedsterAddRebirths: (player, amount) -> ()
	g.SpeedsterAddRebirths = function(player: any, amount: number)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = string.format("rebirth_add_%d_%d", player.UserId, os.time()),
			fingerprint = string.format("rebirth_%d", amount),
			commands = {
				{ kind = "GrantExact", stat = "Rebirths" :: any, amount = amount },
			},
		})
		g.SpeedsterSyncRebirthAttributes(player)
	end

	-- 12. SpeedsterHasProcessedReceipt
	g.SpeedsterHasProcessedReceipt = function(player: any, receiptId: string): boolean
		return ReceiptLedger.HasProcessed(receiptId)
	end

	-- 13. SpeedsterMarkProcessedReceipt
	g.SpeedsterMarkProcessedReceipt = function(player: any, receiptId: string): boolean
		ReceiptLedger.RecordProcessed({
			purchaseId = receiptId,
			userId = player.UserId,
			productId = 0,
			processedAtUnix = os.time(),
		})
		return true
	end

	-- 14. SpeedsterClearProcessedReceipt
	g.SpeedsterClearProcessedReceipt = function(player: any, receiptId: string)
		ReceiptLedger.Clear(receiptId)
	end

	-- 15. SpeedsterGetNextRebirthLevelRequirement: toma rebirthCount (número)
	g.SpeedsterGetNextRebirthLevelRequirement = function(rebirthCount: number): number
		local res = StatsService.NextRebirthRequirement(rebirthCount, {})
		return res.ok and res.value or 5
	end

	-- 16. SpeedsterGetRebirthSpeedGainMultiplier: toma rebirthCount (número)
	g.SpeedsterGetRebirthSpeedGainMultiplier = function(rebirthCount: number): number
		return 1.5 ^ (rebirthCount or 0)
	end

	-- 17. SpeedsterSyncRebirthAttributes
	g.SpeedsterSyncRebirthAttributes = function(player: any)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		local inspect = DataService.Inspect(handle)
		if inspect.ok and inspect.value.profile then
			local r = inspect.value.profile.Rebirths or 0
			if typeof(player.SetAttribute) == "function" then
				local req = g.SpeedsterGetNextRebirthLevelRequirement(r)
				local mult = g.SpeedsterGetRebirthSpeedGainMultiplier(r)
				player:SetAttribute("NextRebirthSpeedRequired", req)
				player:SetAttribute("NextRebirthLevelRequired", req)
				player:SetAttribute("RebirthSpeedGainMultiplier", mult)
				player:SetAttribute("RebirthMultiplier", mult)
				player:SetAttribute("Rebirths", r)
			end
		end
	end

	-- 18. SpeedsterUnlockTrail
	g.SpeedsterUnlockTrail = function(player: any, trailId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = "unlock_trail_" .. trailId,
			fingerprint = trailId,
			commands = { { kind = "GrantTrail", trailId = trailId } },
		})
	end

	-- 19. SpeedsterEquipTrail
	g.SpeedsterEquipTrail = function(player: any, trailId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		if typeof(player.SetAttribute) == "function" then
			player:SetAttribute("EquippedTrailId", trailId)
			player:SetAttribute("EquippedTrail", trailId)
		end
		DataService.SetPreference(handle, "EquippedTrail", trailId)
		DataService.Commit(handle, {
			operationId = string.format("equip_trail_%d_%d", player.UserId, os.time()),
			fingerprint = "equip_trail_" .. tostring(trailId),
			commands = { { kind = "EquipTrail", trailId = trailId } },
		})
	end

	-- 20. SpeedsterUnlockSkin
	g.SpeedsterUnlockSkin = function(player: any, skinId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = "unlock_skin_" .. skinId,
			fingerprint = skinId,
			commands = { { kind = "GrantSkin", skinId = skinId } },
		})
	end

	-- 21. SpeedsterUnlockAura
	g.SpeedsterUnlockAura = function(player: any, auraId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = "unlock_aura_" .. auraId,
			fingerprint = auraId,
			commands = { { kind = "GrantAura", auraId = auraId } },
		})
	end

	-- 22. SpeedsterEquipAura
	g.SpeedsterEquipAura = function(player: any, auraId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		if typeof(player.SetAttribute) == "function" then
			player:SetAttribute("EquippedAuraId", auraId)
			player:SetAttribute("EquippedAura", auraId)
		end
		DataService.SetPreference(handle, "EquippedAura", auraId)
		DataService.Commit(handle, {
			operationId = string.format("equip_aura_%d_%d", player.UserId, os.time()),
			fingerprint = "equip_aura_" .. tostring(auraId),
			commands = { { kind = "EquipAura", auraId = auraId } },
		})
	end

	-- 23. SpeedsterUnlockUpgrade
	g.SpeedsterUnlockUpgrade = function(player: any, upgradeId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = "unlock_upgrade_" .. upgradeId,
			fingerprint = upgradeId,
			commands = { { kind = "GrantUpgrade", upgradeId = upgradeId } },
		})
	end

	-- 24. SpeedsterHasTrail
	g.SpeedsterHasTrail = function(player: any, trailId: string): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local inspect = DataService.Inspect(handle)
		if inspect.ok and inspect.value.profile and inspect.value.profile.OwnedTrails then
			return table.find(inspect.value.profile.OwnedTrails, trailId) ~= nil
		end
		return false
	end

	-- 25. SpeedsterHasAura
	g.SpeedsterHasAura = function(player: any, auraId: string): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local inspect = DataService.Inspect(handle)
		if inspect.ok and inspect.value.profile and inspect.value.profile.OwnedAuras then
			return table.find(inspect.value.profile.OwnedAuras, auraId) ~= nil
		end
		return false
	end
end

return PlayerStatsBridge
