--!strict
-- SpinWheelCatalog.luau
-- The Spin Wheel's six segments, clockwise from the top of the wheel art. The server
-- picks and pays from this list and the client draws the same list, so the segment the
-- wheel stops on is always the reward that was granted.
--
-- Weights are percentages and add up to 100; the wheel shows them on each segment
-- (paid spins are random rewards, and their odds must be visible).

local SpinWheelCatalog = {}

export type Segment = {
	Id: string,
	Kind: string,
	Weight: number,
	Icon: string,
	Rarity: string,
	Tier: string?,
	Minutes: number?,
	Rare: boolean?,
	-- An exclusive prize: what it is ("Aura" or "Skin") and its id.
	Cosmetic: string?,
	CosmeticId: string?,
	-- The slice's text and the prize's name, for prizes that are not an amount.
	Label: string?,
	Title: string?,
}

-- Rarity picks the slice colour: common green, the potion purple, the big Wins gold,
-- Aura 67 light blue (its own colour) and Tung Tung red. Neighbouring slices never share
-- a colour. The odds: 50% common Wins and Speed, 30% potion, 14% big Wins, and the two
-- exclusives that exist nowhere else in the game, Aura 67 (3.5%) and the Tung Tung
-- Sahur skin (2.5%).
SpinWheelCatalog.Segments = {
	{ Id = "WinsSmall", Kind = "Wins", Tier = "Small", Weight = 25, Icon = "Wins", Rarity = "Common" },
	{ Id = "PotionSpeed", Kind = "PotionSpeed", Minutes = 10, Weight = 30, Icon = "PotionSpeed", Rarity = "Epic" },
	{ Id = "SpeedSmall", Kind = "Speed", Tier = "Small", Weight = 25, Icon = "Speed", Rarity = "Common" },
	{ Id = "Aura67", Kind = "Exclusive", Cosmetic = "Aura", CosmeticId = "Aura67", Label = "AURA 67", Title = "Aura 67",
		Weight = 3.5, Icon = "Aura67", Rarity = "Rare", Rare = true },
	{ Id = "WinsLarge", Kind = "Wins", Tier = "Large", Weight = 14, Icon = "Wins", Rarity = "Legendary" },
	{ Id = "TungTung", Kind = "Exclusive", Cosmetic = "Skin", CosmeticId = "TungTungSuit", Label = "TUNG TUNG", Title = "Tung Tung Sahur",
		Weight = 2.5, Icon = "TungTung", Rarity = "Mythic", Rare = true },
} :: { Segment }

-- Slice colours as gradients in the style of the designer's buttons: light at the rim,
-- deeper towards the centre, like a button is light on top. Each stop is { Time, RGB },
-- Time 0 at the rim and 1 at the centre. Common is the Spin button's own green.
SpinWheelCatalog.RarityGradients = {
	Common = { { 0, { 38, 255, 0 } }, { 0.46, { 74, 248, 0 } }, { 1, { 83, 167, 19 } } },
	Epic = { { 0, { 214, 130, 255 } }, { 0.46, { 164, 70, 246 } }, { 1, { 104, 30, 178 } } },
	Legendary = { { 0, { 255, 230, 80 } }, { 0.46, { 255, 186, 0 } }, { 1, { 214, 118, 0 } } },
	Rare = { { 0, { 140, 232, 255 } }, { 0.46, { 52, 192, 255 } }, { 1, { 24, 118, 214 } } },
	Mythic = { { 0, { 255, 120, 120 } }, { 0.46, { 240, 40, 70 } }, { 1, { 150, 10, 40 } } },
}

-- The colour of a rarity at `time` (0 rim .. 1 centre), as RGB.
function SpinWheelCatalog.RarityColorAt(rarity: string, time: number): { number }
	local stops = SpinWheelCatalog.RarityGradients[rarity] or SpinWheelCatalog.RarityGradients.Common
	time = math.clamp(time, 0, 1)
	for index = 2, #stops do
		local a, b = stops[index - 1], stops[index]
		if time <= b[1] then
			local span = b[1] - a[1]
			local mix = if span > 0 then (time - a[1]) / span else 0
			return {
				math.floor(a[2][1] + (b[2][1] - a[2][1]) * mix + 0.5),
				math.floor(a[2][2] + (b[2][2] - a[2][2]) * mix + 0.5),
				math.floor(a[2][3] + (b[2][3] - a[2][3]) * mix + 0.5),
			}
		end
	end
	return stops[#stops][2]
end

-- The art each segment shows, from the game's own HUD and reward icons.
SpinWheelCatalog.IconImages = {
	Wins = "rbxassetid://15540211845",
	Speed = "rbxassetid://18209576965",
	PotionSpeed = "rbxassetid://71111471194517",
	PotionWins = "rbxassetid://89981527304241",
	Rare = "rbxassetid://138814004538031",
	Aura67 = "rbxassetid://127283711015110",
	-- The Tung Tung rig's own asset thumbnail (SuitCatalog's PreviewAssetId).
	TungTung = "rbxthumb://type=Asset&id=114124284706337&w=150&h=150",
}

-- What an exclusive slice pays once its prize is already owned: a shop cosmetic the
-- player does not own yet, cheapest first, and after those, Wins.
SpinWheelCatalog.RareCosmetics = {
	{ Type = "Aura", Id = "Aura06" },
	{ Type = "Trail", Id = "Trail06" },
	{ Type = "Aura", Id = "Aura03" },
	{ Type = "Trail", Id = "Trail03" },
	{ Type = "Aura", Id = "Aura04" },
	{ Type = "Trail", Id = "Trail04" },
}

-- What an exclusive slice pays once the exclusive and every cosmetic above are owned.
SpinWheelCatalog.RareFallbackWinsMultiplier = 3

local function finite(value: any, fallback: number): number
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end
	return number
end

-- Rounds to two significant figures so rewards read cleanly: 12,345 -> 12,000.
function SpinWheelCatalog.RoundNice(value: number): number
	value = math.max(0, finite(value, 0))
	if value < 100 then
		return math.floor(value + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

-- Wins scale with Level: a Level 100 player gets 25K on the small segment.
-- Wins scale with Level (a Level 100 player gets 25K on the small segment) and, once the
-- world is known, with what a lap of that world pays: `lap` x `shares` (Small, Large),
-- whichever is more. A World 3 lap pays 26.5M, so its big prize is about 16M.
export type LapShares = { Small: number, Large: number }
function SpinWheelCatalog.WinsAmount(tier: string?, level: number, lap: number?, shares: LapShares?): number
	local small = math.clamp(math.floor(finite(level, 1)) * 250, 1000, 250000)
	local amount = if tier == "Large" then small * 5 else small
	local laps = finite(lap, 0)
	if laps > 0 then
		local share = if tier == "Large" then finite(shares and shares.Large, 0.6) else finite(shares and shares.Small, 0.15)
		amount = math.max(amount, laps * share)
	end
	return SpinWheelCatalog.RoundNice(amount)
end

-- Speed scales with the player's own Speed, like the Speed purchases do, because Speed
-- grows by orders of magnitude over a playthrough.
function SpinWheelCatalog.SpeedAmount(tier: string?, speed: number): number
	local share = if tier == "Large" then 0.25 else 0.05
	local floor = if tier == "Large" then 25000 else 2500
	return SpinWheelCatalog.RoundNice(math.max(floor, finite(speed, 0) * share))
end

export type WinsPurchaseSettings = { PrizeMultiple: number?, MinimumCost: number?, FixedCost: number? }

-- The Wins price of one spin: the large Wins prize x PrizeMultiple (never below
-- MinimumCost), raised by the permanent Wins multiplier like progression prices are.
function SpinWheelCatalog.WinsSpinCost(
	level: number,
	permanentWinsMultiplier: number,
	settings: WinsPurchaseSettings?,
	exponent: number?
): number
	-- A flat price, when the game sets one.
	local fixed = finite(settings and settings.FixedCost, 0)
	if fixed > 0 then
		return SpinWheelCatalog.RoundNice(fixed)
	end
	local multiple = math.max(1, finite(settings and settings.PrizeMultiple, 20))
	local minimum = math.max(0, finite(settings and settings.MinimumCost, 50000))
	local base = math.max(minimum, SpinWheelCatalog.WinsAmount("Large", level) * multiple)
	local multiplier = math.max(1, finite(permanentWinsMultiplier, 1))
	local power = math.clamp(finite(exponent, 0.5), 0, 1)
	return SpinWheelCatalog.RoundNice(base * multiplier ^ power)
end

function SpinWheelCatalog.TotalWeight(): number
	local total = 0
	for _, segment in SpinWheelCatalog.Segments do
		total += segment.Weight
	end
	return total
end

-- `roll` is a number in [0, 1). Returns the segment index it lands on.
function SpinWheelCatalog.Pick(roll: number): number
	local target = math.clamp(finite(roll, 0), 0, 0.999999) * SpinWheelCatalog.TotalWeight()
	local running = 0
	for index, segment in SpinWheelCatalog.Segments do
		running += segment.Weight
		if target < running then
			return index
		end
	end
	return #SpinWheelCatalog.Segments
end

-- "32%" for a whole percentage, "2.5%" otherwise.
function SpinWheelCatalog.OddsText(index: number): string
	local segment = SpinWheelCatalog.Segments[index]
	if not segment then
		return ""
	end
	local percent = segment.Weight / SpinWheelCatalog.TotalWeight() * 100
	local text = string.format("%.1f", percent)
	text = string.gsub(text, "%.0$", "")
	return text .. "%"
end

-- The HUD's suffixes, so the wheel reads amounts the same way the rest of the game does.
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

function SpinWheelCatalog.FormatNumber(value: number): string
	value = math.max(0, finite(value, 0))
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(value) / 3) + 1
	local scaled = value / (1000 ^ (tier - 1))
	-- 999.96K prints as 1000K; carry it into the next suffix instead.
	if scaled >= 999.95 then
		tier += 1
		scaled /= 1000
	end
	if tier > #SUFFIXES then
		return string.format("%.2e", value)
	end
	local text = if scaled >= 100 then string.format("%.0f", scaled) elseif scaled >= 10 then string.format("%.1f", scaled) else string.format("%.2f", scaled)
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. SUFFIXES[tier]
end

-- Lap: what a lap of the player's world pays; Shares: the Wins segments' shares of it.
export type Context = { Level: number, Speed: number, Lap: number?, Shares: LapShares? }

-- The short text a segment shows on the wheel for this player: the real amount.
function SpinWheelCatalog.ShortLabel(index: number, context: Context): string
	local segment = SpinWheelCatalog.Segments[index]
	if not segment then
		return ""
	end
	if segment.Kind == "Wins" then
		return SpinWheelCatalog.FormatNumber(SpinWheelCatalog.WinsAmount(segment.Tier, context.Level, context.Lap, context.Shares))
	elseif segment.Kind == "Speed" then
		return "+" .. SpinWheelCatalog.FormatNumber(SpinWheelCatalog.SpeedAmount(segment.Tier, context.Speed))
	elseif segment.Minutes then
		return "2x " .. tostring(segment.Minutes) .. "m"
	elseif segment.Label then
		return segment.Label
	elseif segment.Rare then
		return "RARE"
	end
	return ""
end

-- A short countdown: M:SS under an hour ("4:07"), H:MM from an hour on ("2:59").
function SpinWheelCatalog.ShortClock(seconds: number): string
	local whole = math.max(0, math.ceil(finite(seconds, 0)))
	if whole >= 3600 then
		return string.format("%d:%02d", whole // 3600, whole % 3600 // 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

export type HudView = {
	Loading: boolean?,
	FreeAvailable: boolean?,
	Tickets: number?,
	SecondsToFree: number?,
	PriceRobux: number?,
	ShowPrice: boolean?,
}

-- What the Main HUD's Spin Wheel button says, and what its badge says (nil hides it):
--   * a free spin is ready (or its wait is over): "Free Spin!", the badge counts every spin
--     ready when there are tickets too, "!" otherwise;
--   * spin tickets: "2x Spin!", the badge counts them;
--   * neither: the wait for the next free spin ("4:07"), taking turns with "Spin 16 R$"
--     when spins are for sale (PriceRobux) and ShowPrice is this turn.
function SpinWheelCatalog.HudButton(view: HudView): (string, string?)
	if view.Loading then
		return "Spin", nil
	end
	local tickets = math.max(0, math.floor(finite(view.Tickets or 0, 0)))
	local secondsToFree = finite(view.SecondsToFree or 0, 0)
	if view.FreeAvailable or secondsToFree <= 0 then
		return "Free Spin!", if tickets > 0 then tostring(tickets + 1) else "!"
	end
	if tickets > 0 then
		return tostring(tickets) .. "x Spin!", tostring(tickets)
	end
	local price = view.PriceRobux and math.floor(finite(view.PriceRobux, 0))
	if view.ShowPrice and price and price > 0 then
		return "Spin " .. tostring(price) .. " R$", nil
	end
	return SpinWheelCatalog.ShortClock(secondsToFree), nil
end

return SpinWheelCatalog
