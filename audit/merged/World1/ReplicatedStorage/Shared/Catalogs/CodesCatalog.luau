--!strict
-- CodesCatalog.luau
-- Catálogo centralizado y autoritativo de códigos promocionales para Speedter Game.

export type PotionReward = {
	Type: "Speed" | "Wins",
	DurationMinutes: number,
	Multiplier: number?,
}

export type CodeDefinition = {
	Marker: string,
	Speed: number?,
	Wins: number?,
	Rebirths: number?,
	FlightMinutes: number?,
	CustomMessage: string?,
	Potion: PotionReward?,
	Potions: { PotionReward }?,
	ProportionalRewards: boolean?,
}

-- Every previous promo code has been retired. Retiring a code is safe: the claim
-- markers stay in each player's profile, so nobody who already redeemed one is
-- affected, and an unknown code simply reports "invalid".
--
-- BOOST is the only live code. Change its rewards here and nowhere else - the
-- Codes modal and the Update Logs banner are both generated from this table.
local CodesCatalog: { [string]: CodeDefinition } = {
	boost = {
		Marker = "Code_Boost_v1",
		Potions = {
			{ Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		},
		ProportionalRewards = true,
		CustomMessage = "⚡ BOOST redeemed! 2x Speed and 2x Wins for 15 minutes.",
	},
}

-- Codes shown to players, in display order. Keep in sync with the table above.
CodesCatalog.Active = { "BOOST" }

function CodesCatalog.Normalize(input: string?): string
	if type(input) ~= "string" or #input > 100 then
		return ""
	end
	return string.lower((input:gsub("%s+", "")))
end

function CodesCatalog.Get(rawCode: string?): CodeDefinition?
	local key = CodesCatalog.Normalize(rawCode)
	return CodesCatalog[key]
end

return CodesCatalog
