--!strict
-- DoubleWinsPad.luau
-- The x2 Wins pads, shared by both worlds.
--
-- The x2 pads are unlocked by ONE permanent gamepass, Config.DoubleWinsPadGamePassId
-- (1941409601, sold as "2X Victory" in the shop). Buy it once and every x2 pad pays
-- double for good - the same model the OG game shipped with.
--
-- It is NOT the x2..x32 Wins ladder. The ladder is a set of developer products
-- (Config.PermanentWinsMultiplierProducts) that multiplies every wins reward; the
-- two are bought separately and stack in Shared.WinsMath.
--
-- The per-claim developer product that replaced the pass for a while (3712435111,
-- "2x Wins (PAD)") is retired. Nothing prompts it any more; SpeedProductPurchases
-- only honours a receipt that was already in flight.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WinsMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinsMath"))
local PadTouchService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PadTouchService"))

local DoubleWinsPad = {}

DoubleWinsPad.GamePassId = tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
DoubleWinsPad.PromptCooldown = 2
DoubleWinsPad.Multiplier = WinsMath.PadDoubleMultiplier
-- A purchase only re-checks the pad the player was standing on if it lands this soon.
DoubleWinsPad.PendingSeconds = 120
-- A failed ownership lookup is retried, but not on every single touch.
DoubleWinsPad.LookupRetrySeconds = 10

-- Ownership is kept as player attributes so the HUD and the shop read the same fact
-- the pads do. Only server code holding proof of the pass writes them: the Roblox
-- ownership lookup, the purchase-finished event, and admin grants. Attributes a
-- client sets on itself never replicate, so they cannot unlock a pad.
DoubleWinsPad.OwnedAttributes = { "DoubleWinsPadUnlocked", "TwoXVictoryOwned" }

type LookupState = { inFlight: boolean, checked: boolean, failedAt: number? }
type Pending = { pad: BasePart, at: number }

local lookups: { [Player]: LookupState } = {}
local pending: { [Player]: Pending } = {}
local lastPromptAt: { [Player]: number } = {}

function DoubleWinsPad.MarkOwned(player: Player)
	for _, name in DoubleWinsPad.OwnedAttributes do
		player:SetAttribute(name, true)
	end
end

-- Asks Roblox at most once per session per player. Returns nil when there is no
-- new answer (a lookup is already running, or the last one failed recently).
local function lookUpOwnership(player: Player): boolean?
	local state = lookups[player]
	if not state then
		state = { inFlight = false, checked = false }
		lookups[player] = state
	end
	if state.checked or state.inFlight then
		return nil
	end
	if state.failedAt and os.clock() - state.failedAt < DoubleWinsPad.LookupRetrySeconds then
		return nil
	end

	state.inFlight = true
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DoubleWinsPad.GamePassId)
	end)
	state.inFlight = false

	if not ok then
		state.failedAt = os.clock()
		return nil
	end
	state.checked = true
	if owns == true then
		DoubleWinsPad.MarkOwned(player)
	end
	return owns == true
end

-- True when this player's x2 pads pay double. May yield once per session for the
-- ownership lookup, which covers a player who reaches a pad before the join check.
function DoubleWinsPad.IsEntitled(player: Player): boolean
	if player:GetAttribute("DoubleWinsPadUnlocked") == true or player:GetAttribute("TwoXVictoryOwned") == true then
		return true
	end
	return lookUpOwnership(player) == true
end

function DoubleWinsPad.PendingPad(player: Player): BasePart?
	local entry = pending[player]
	return entry and entry.pad or nil
end

-- Called once the x2 claim has been paid.
function DoubleWinsPad.Clear(player: Player)
	pending[player] = nil
end

-- Remember which x2 pad the player is standing on and open the gamepass prompt.
-- Nothing is paid here. If the purchase goes through, PadTouchService re-checks
-- the player against that same pad and the normal claim path (MovementGuard,
-- cooldowns, RewardPadClaims) pays it - or nothing happens if they walked away.
function DoubleWinsPad.RequestPurchase(player: Player, pad: BasePart, logTag: string)
	pending[player] = { pad = pad, at = os.clock() }

	local state = lookups[player]
	if state and state.inFlight then
		-- The answer may be "already owned"; do not prompt over the top of it.
		return
	end

	local now = os.clock()
	if now - (lastPromptAt[player] or -math.huge) < DoubleWinsPad.PromptCooldown then
		return
	end
	lastPromptAt[player] = now

	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, DoubleWinsPad.GamePassId)
	end)
	if not ok then
		warn(logTag .. " Could not prompt the x2 pads gamepass: " .. tostring(err))
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
	if tonumber(gamePassId) ~= DoubleWinsPad.GamePassId or player.Parent ~= Players then
		return
	end

	local owns = wasPurchased == true
	if not owns then
		-- The prompt also closes without a purchase when the pass is already owned,
		-- which is what a player who beat the join lookup to the pad will see.
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DoubleWinsPad.GamePassId)
		end)
		owns = ok and result == true
	end

	local waiting = pending[player]
	pending[player] = nil
	if not owns then
		return
	end

	DoubleWinsPad.MarkOwned(player)
	if waiting and waiting.pad.Parent and os.clock() - waiting.at <= DoubleWinsPad.PendingSeconds then
		PadTouchService.ResumePad(player, waiting.pad)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lookups[player] = nil
	pending[player] = nil
	lastPromptAt[player] = nil
end)

return DoubleWinsPad
