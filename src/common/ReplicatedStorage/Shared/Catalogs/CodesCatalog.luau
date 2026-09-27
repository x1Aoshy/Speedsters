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
-- Change rewards here and nowhere else - the
-- Codes modal and the Update Logs banner are both generated from this table.
local CodesCatalog: { [string]: CodeDefinition } = {
	boost = {
		Marker = "Code_Boost_v1",
		Potions = {
			{ Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		},
		CustomMessage = "⚡ BOOST redeemed! 2x Speed and 2x Wins for 15 minutes.",
	},
	update3 = {
		Marker = "Code_Update3_v1",
		Potions = {
			{ Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 10, Multiplier = 2 },
		},
		CustomMessage = "UPDATE3 redeemed! 2x Speed for 15 minutes and 2x Wins for 10 minutes.",
	},
	newworld = {
		Marker = "Code_NewWorld_v1",
		Potion = { Type = "Speed", DurationMinutes = 20, Multiplier = 2 },
		CustomMessage = "NEWWORLD redeemed! 2x Speed for 20 minutes.",
	},
	adminparty = {
		Marker = "Code_AdminParty_v1",
		Potion = { Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		CustomMessage = "ADMINPARTY redeemed! 2x Wins for 15 minutes.",
	},
	-- 2026-09-26 (owner): the Update 4 codes. Potions like the Update 3 codes (one-time per
	-- player through their Marker, case-insensitive through Normalize, no expiry); the
	-- headline code a little bigger than UPDATE3's 15 + 10 minutes.
	update4ishere = {
		Marker = "Code_Update4IsHere_v1",
		Potions = {
			{ Type = "Speed", DurationMinutes = 20, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		},
		CustomMessage = "UPDATE4ISHERE redeemed! 2x Speed for 20 minutes and 2x Wins for 15 minutes.",
	},
	races = {
		Marker = "Code_Races_v1",
		Potion = { Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
		CustomMessage = "RACES redeemed! 2x Speed for 15 minutes.",
	},
	eggman = {
		Marker = "Code_Eggman_v1",
		Potion = { Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		CustomMessage = "EGGMAN redeemed! 2x Wins for 15 minutes.",
	},
}

-- Codes shown to players, in display order. Every one must redeem (audit/test_promo_codes).
-- 2026-09-26 (owner): the Update Logs banner advertises the Update 4 codes; the Update 3
-- codes and BOOST above still redeem.
CodesCatalog.Active = { "UPDATE4ISHERE", "RACES", "EGGMAN" }

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
