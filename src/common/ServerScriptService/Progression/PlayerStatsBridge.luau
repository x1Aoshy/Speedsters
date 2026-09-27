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
-- SpeedsterGrantExactStat builds its fingerprint with GenerateGUID; without this the admin
-- give commands always errored ("attempt to index nil with 'GenerateGUID'").
local HttpService = if inRoblox then game:GetService("HttpService") else nil
local Config =if inRoblox then require(game:GetService("ReplicatedStorage").Shared.Config) else {}
local PotionServer = if inRoblox then require(script.Parent.Parent.Services.PotionServer) else nil
-- Shared.WinsMath is the only place that decides how a Wins reward is multiplied.
local WinsMath = if inRoblox then require(game:GetService("ReplicatedStorage").Shared.WinsMath) else nil
-- Saved in OwnedUpgrades once the Rebirth gamepass has paid its one rebirth.
local REBIRTH_PASS_MARKER = "__RebirthPassGranted"

local function attribute(player: any, key: string): number
	local value = player:GetAttribute(key)
	return if type(value) == "number" and value == value and math.abs(value) ~= math.huge and value >= 0 then value else 1
end

-- Update 4 (2026-09-25): Playtime Boost + Streak (Social/RetentionService publishes the attribute,
-- 1..3.4). Races pay their own rewards, so it is x1 while RaceActive.
local function retentionMultiplier(player: any): number
	if player:GetAttribute("RaceActive") == true then
		return 1
	end
	return math.clamp(attribute(player, "RetentionSpeedGainMultiplier"), 1, 10)
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

-- Running gains tick ten times a second per player. Sending one popup remote per
-- tick put a per-player packet storm on the wire for an effect the client has to
-- coalesce anyway, so pending running gains are batched here and flushed at a
-- fixed rate; the payload always carries the newest speed total.
local RUNNING_POPUP_INTERVAL = 0.2
local pendingRunningPopup: { [any]: any } = setmetatable({}, { __mode = "k" })
local lastRunningPopupAt: { [any]: number } = setmetatable({}, { __mode = "k" })

local function sendPopup(player: any, payload: any)
	game:GetService("ReplicatedStorage").Remotes.SpeedGainPopup:FireClient(player, payload)
end

local function queuePopup(player: any, payload: any)
	if payload.IsRunningPopup ~= true then
		sendPopup(player, payload)
		return
	end

	local pending = pendingRunningPopup[player]
	if pending then
		payload.Amount = (tonumber(pending.Amount) or 0) + (tonumber(payload.Amount) or 0)
	end
	pendingRunningPopup[player] = payload

	local now = os.clock()
	local last = lastRunningPopupAt[player] or -math.huge
	if now - last >= RUNNING_POPUP_INTERVAL then
		lastRunningPopupAt[player] = now
		pendingRunningPopup[player] = nil
		sendPopup(player, payload)
		return
	end

	if pending then
		-- A flush is already scheduled for this player.
		return
	end
	task.delay(RUNNING_POPUP_INTERVAL - (now - last), function()
		local queued = pendingRunningPopup[player]
		pendingRunningPopup[player] = nil
		if queued and player.Parent then
			lastRunningPopupAt[player] = os.clock()
			sendPopup(player, queued)
		end
	end)
end

-- Registra las 23 exportaciones globales canónicas en _G
function PlayerStatsBridge.RegisterGlobals()
	local g = (_G :: any)

	-- 1. SpeedsterAddSpeed
	g.SpeedsterAddSpeed = function(player: any, baseAmount: number, popupData: any?): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		-- PeekSpeed, not Inspect: this runs twice a second for every moving player, and each
		-- Inspect copied the whole profile (twice here, plus once more for the notification).
		local before = DataService.PeekSpeed(player.UserId)
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
			disco = attribute(player, "DiscoSpeedGainMultiplier"),
			retention = retentionMultiplier(player),
		})
		if res.ok and popupData and inRoblox then
			local after = DataService.PeekSpeed(player.UserId)
			local diff = after - before
			local wholeGain = (typeof(res) == "table" and res.whole and res.whole > 0 and res.whole) or nil
			local amount = (diff > 0 and diff) or wholeGain or tonumber(popupData.VisualAmount) or tonumber(baseAmount) or 1
			if diff > 0 or wholeGain or popupData.ForcePopup then
				local payload = table.clone(popupData)
				payload.Amount = amount
				-- The owner's HUD counts from this, so it stays smooth while the replicated
				-- stats (leaderstats, RawSpeed, WalkSpeed) now follow once a second.
				payload.TotalSpeed = after
				if payload.IsRunningPopup then
					payload.BurstCount = payload.IsBoostingPopup and 2 or 1
				end
				queuePopup(player, payload)
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
			* (attribute(player, "TrailSpeedGainMultiplier") or p.TrailSpeedGainMultiplier or 1)
			* (attribute(player, "AuraSpeedGainMultiplier") or p.AuraSpeedGainMultiplier or 1)
			* (p.UpgradeSpeedGainMultiplier or 1)
			* (p.GamepassSpeedGainMultiplier or 1)
			* (math.max(attribute(player, "PermanentBaseSpeedMultiplier"), p.PermanentBaseSpeedMultiplier or 1))
			* retentionMultiplier(player)
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

	-- 6b. SpeedsterGetWinsMultiplier: every multiplier that applies to a Wins reward
	-- (permanent tier x VIP x potion x confetti x server boost). Reward pads, product
	-- grants and the client billboards all read this same number.
	g.SpeedsterGetWinsMultiplier = function(player: any): number
		local permanent = g.SpeedsterGetPermanentWinsMultiplier(player)
		if not WinsMath then return permanent end
		local components = WinsMath.GetComponents(player)
		-- The durable profile can be ahead of the replicated attribute right after a purchase.
		local total = components.total
		if permanent > components.permanent and components.permanent > 0 then
			total = total / components.permanent * permanent
		end
		if type(total) ~= "number" or total ~= total or total < 1 or total == math.huge then return permanent end
		return total
	end

	-- 2026-09-21: both setters only RAISE. Their callers (join pass refreshes, the gamepass
	-- purchase handlers, the legacy grant transactions) compute the value from the attribute,
	-- which can lag a receipt committing at the same moment, and a plain write then undid a
	-- paid rung (x8 -> x4). Nothing legitimate lowers a paid multiplier through here: the
	-- admin Full Wipe uses the WipeProfile reducer, and the legacy transactions' Rollback
	-- (only reached when the modular DataService is off) now leaves the profile as it is.
	local function raiseMultiplier(player: any, key: string, multiplier: number, fingerprint: string)
		local value = tonumber(multiplier)
		if value == nil or value ~= value or value == math.huge or value < 0 then return end
		local current = tonumber(player:GetAttribute(key))
		if current ~= nil and current == current and current ~= math.huge then
			value = math.max(current, value)
		end
		player:SetAttribute(key, value)
		local handle = DataService.GetHandle(player.UserId)
		if handle then
			DataService.Commit(handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = fingerprint .. tostring(value),
				commands = {
					{ kind = "SetPersistent", key = key, value = value, monotonic = true }
				}
			})
		end
	end

	g.SpeedsterSetPermanentBaseSpeedMultiplier = function(player: any, multiplier: number)
		raiseMultiplier(player, "PermanentBaseSpeedMultiplier", multiplier, "speed_mult_")
	end

	g.SpeedsterSetPermanentWinsMultiplier = function(player: any, multiplier: number)
		raiseMultiplier(player, "PermanentWinsMultiplier", multiplier, "wins_mult_")
	end

	-- 7. SpeedsterSyncSuitSpeedGainMultiplier
	g.SpeedsterSyncSuitSpeedGainMultiplier = function(player: any)
		local multiplier = g.SpeedsterGetSuitSpeedGainMultiplierForSkin(player:GetAttribute("EquippedSkin"))
		player:SetAttribute("SuitSpeedGainMultiplier", multiplier)
		player:SetAttribute("SkinSpeedGainMultiplier", multiplier)
	end

	-- 8. SpeedsterSavePlayer
	g.SpeedsterSavePlayer = function(player: any, reason: string?, waitForCompletion: boolean?): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local inspect=DataService.Inspect(handle)
		if not inspect.ok or not inspect.value.profile then return false end
		local commands={}
		for _,key in {"FirstTimeTutorialSeen","World2Unlocked","World3Unlocked"} do
			if player:GetAttribute(key)==true and inspect.value.profile[key]~=true then table.insert(commands,{kind="SetPersistent",key=key,value=true}) end
		end
		local seen=tonumber(player:GetAttribute("LastSeenUpdateLog")) or 0
		if seen>(inspect.value.profile.LastSeenUpdateLog or 0) then table.insert(commands,{kind="SetPersistent",key="LastSeenUpdateLog",value=seen,monotonic=true}) end

		local currentTrail = player:GetAttribute("EquippedTrailId") or player:GetAttribute("EquippedTrail")
		if currentTrail ~= nil and currentTrail ~= (inspect.value.profile.EquippedTrail or "") then
			table.insert(commands, { kind = "EquipTrail", trailId = tostring(currentTrail) })
			DataService.SetPreference(handle, "EquippedTrail", tostring(currentTrail))
		end

		local currentAura = player:GetAttribute("EquippedAuraId") or player:GetAttribute("EquippedAura")
		if currentAura ~= nil and currentAura ~= (inspect.value.profile.EquippedAura or "") then
			table.insert(commands, { kind = "EquipAura", auraId = tostring(currentAura) })
			DataService.SetPreference(handle, "EquippedAura", tostring(currentAura))
		end

		if #commands>0 then
			local committed=DataService.Commit(handle,{operationId=DataService.NewOperationId(),fingerprint="legacy-flags",commands=commands})
			if committed.kind~="Committed" and committed.kind~="AlreadyCommitted" then return false end
		end
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
	-- Returns (granted, creditedAmount) so a caller that must undo the grant can
	-- debit exactly what was paid; GrantExact refuses negative amounts.
	g.SpeedsterAddWins = function(player: any, baseGain: number): (boolean, number)
		local handle = DataService and DataService.GetHandle(player.UserId)
		if not handle then return false, 0 end
		-- Preserve OG reward semantics: permanent wins bonuses and 2x Wins potion apply to rewards.
		-- Exact purchased grants continue to use SpeedsterGrantExactStat.
		local amount = tonumber(baseGain) or 0
		if amount > 0 then
			amount = math.floor(amount * g.SpeedsterGetWinsMultiplier(player))
		end
		local commitRes = DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = "add_wins",
			commands = {
				{ kind = "GrantExact", stat = "Wins", amount = amount },
			},
		})
		local granted = commitRes ~= nil and (commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted")
		return granted, if granted then amount else 0
	end

	-- 9b. SpeedsterSpendWins
	g.SpeedsterSpendWins = function(player: any, amount: number): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local commitRes = DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
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

		if statName ~= "Speed" and statName ~= "Wins" and statName ~= "SpinTickets" and statName ~= "Spins" and statName ~= "Tickets" then
			return false, "Invalid stat name"
		end

		local command = if statName == "SpinTickets" or statName == "Spins" or statName == "Tickets"
			then { kind = "GrantSpinTickets", amount = amount }
			else { kind = "GrantExact", stat = statName :: any, amount = amount }

		local commitRes = DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = string.format("exact_%s_%d_%s", statName, amount, if HttpService then HttpService:GenerateGUID(false) else DataService.NewOperationId()),
			commands = { command },
		})

		if commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted" then
			if statName == "SpinTickets" or statName == "Spins" or statName == "Tickets" then
				local cur = tonumber(player:GetAttribute("SpinTickets")) or 0
				player:SetAttribute("SpinTickets", cur + amount)
				if type(g.SpeedsterRefreshSpinWheel) == "function" then
					pcall(g.SpeedsterRefreshSpinWheel, player)
				end
			end
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
			operationId = DataService.NewOperationId(),
			fingerprint = string.format("rebirth_%d", amount),
			commands = {
				{ kind = "GrantExact", stat = "Rebirths" :: any, amount = amount },
			},
		})
		g.SpeedsterSyncRebirthAttributes(player)
	end

	-- 11b. SpeedsterGrantRebirthPassOnce: (player) -> granted
	-- The Rebirth gamepass gives ONE rebirth, ever. The grant and its marker are written in the
	-- same commit, so a rejoin, a world change or the purchase prompt racing the join check can
	-- never add a second one (it used to be guarded by a player attribute that is not saved,
	-- which gave +1 rebirth on every join).
	g.SpeedsterGrantRebirthPassOnce = function(player: any): boolean
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return false end
		local view = DataService.Inspect(handle)
		if not (view.ok and view.value.profile) then return false end
		if table.find(view.value.profile.OwnedUpgrades, REBIRTH_PASS_MARKER) then return false end
		local commitRes = DataService.Commit(handle, {
			-- Fixed identity: two concurrent callers dedupe to one commit.
			operationId = "rebirth_pass_grant",
			fingerprint = "rebirth_pass_grant_v1",
			commands = {
				{ kind = "GrantUpgrade", upgradeId = REBIRTH_PASS_MARKER },
				{ kind = "GrantExact", stat = "Rebirths" :: any, amount = 1 },
			},
		})
		g.SpeedsterSyncRebirthAttributes(player)
		return commitRes.kind == "Committed"
	end

	-- 12. SpeedsterHasProcessedReceipt
	g.SpeedsterHasProcessedReceipt = function(player: any, receiptId: string): boolean
		local handle=DataService.GetHandle(player.UserId)
		local view=handle and DataService.Inspect(handle)
		return view and view.ok and view.value.profile.ProcessedReceipts[receiptId]~=nil or false
	end

	-- 13. SpeedsterMarkProcessedReceipt
	g.SpeedsterMarkProcessedReceipt = function(player: any, receiptId: string): boolean
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return false end
		local result=DataService.Commit(handle,{operationId="receipt:"..receiptId,receiptId=receiptId,fingerprint="legacy-receipt",commands={}})
		return result.kind=="Committed" or result.kind=="AlreadyCommitted"

	end

	-- 14. SpeedsterClearProcessedReceipt
	g.SpeedsterClearProcessedReceipt = function(player: any, receiptId: string)
		-- A confirmed receipt is immutable; uncertain saves are retried, never rolled back.
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
			operationId = DataService.NewOperationId(),
			fingerprint = trailId,
			commands = { { kind = "GrantTrail", trailId = trailId } },
		})
	end

	-- 19. SpeedsterEquipTrail
	g.SpeedsterEquipTrail = function(player: any, trailId: string, multiplier: any)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
		local entry = Catalog.GetEntry("Trail", trailId or "")
		local mult = tonumber(multiplier) or (entry and (tonumber(entry.SpeedMultiplier) or 1) or 1)
		if typeof(player.SetAttribute) == "function" then
			player:SetAttribute("EquippedTrailId", trailId or "")
			player:SetAttribute("EquippedTrail", trailId or "")
			player:SetAttribute("TrailSpeedGainMultiplier", mult)
		end
		-- CosmeticService re-persists on every attribute change, and StatsProjection
		-- echoes the durable value back into that attribute after every commit -
		-- including the ten speed commits a second a running player produces. Writing
		-- only on a real change stops that echo from re-committing (and briefly
		-- reverting) the player's selection.
		local inspect = DataService.Inspect(handle)
		if inspect.ok and inspect.value.profile and (inspect.value.profile.EquippedTrail or "") == (trailId or "") then
			return
		end
		DataService.SetPreference(handle, "EquippedTrail", trailId or "")
		DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = "equip_trail_" .. tostring(trailId),
			commands = { { kind = "EquipTrail", trailId = trailId or "" } },
		})
	end

	-- 20. SpeedsterUnlockSkin
	g.SpeedsterUnlockSkin = function(player: any, skinId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = skinId,
			commands = { { kind = "GrantSkin", skinId = skinId } },
		})
	end

	-- 21. SpeedsterUnlockAura
	g.SpeedsterUnlockAura = function(player: any, auraId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = auraId,
			commands = { { kind = "GrantAura", auraId = auraId } },
		})
	end

	-- 22. SpeedsterEquipAura
	g.SpeedsterEquipAura = function(player: any, auraId: string, multiplier: any)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
		local entry = Catalog.GetEntry("Aura", auraId or "")
		local mult = tonumber(multiplier) or (entry and (tonumber(entry.SpeedMultiplier) or 1) or 1)
		if typeof(player.SetAttribute) == "function" then
			player:SetAttribute("EquippedAuraId", auraId or "")
			player:SetAttribute("EquippedAura", auraId or "")
			player:SetAttribute("AuraSpeedGainMultiplier", mult)
		end
		-- See SpeedsterEquipTrail: only commit when the durable value really changes.
		local inspect = DataService.Inspect(handle)
		if inspect.ok and inspect.value.profile and (inspect.value.profile.EquippedAura or "") == (auraId or "") then
			return
		end
		DataService.SetPreference(handle, "EquippedAura", auraId or "")
		DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
			fingerprint = "equip_aura_" .. tostring(auraId),
			commands = { { kind = "EquipAura", auraId = auraId or "" } },
		})
	end

	-- 23. SpeedsterUnlockUpgrade
	g.SpeedsterUnlockUpgrade = function(player: any, upgradeId: string)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then return end
		DataService.Commit(handle, {
			operationId = DataService.NewOperationId(),
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
