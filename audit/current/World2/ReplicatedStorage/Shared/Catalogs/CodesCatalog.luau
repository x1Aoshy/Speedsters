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
	Potion: PotionReward?,
	Potions: { PotionReward }?,
	ProportionalRewards: boolean?,
}

local CodesCatalog: { [string]: CodeDefinition } = {
	sorry4bugs = {
		Marker = "Code_Sorry4Bugs_v1",
		Rebirths = 2,
		Potions = {
			{ Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		},
		ProportionalRewards = true,
	},
	thanks4playing = {
		Marker = "Code_Thanks4Playing_v1",
		Potions = {
			{ Type = "Speed", DurationMinutes = 15, Multiplier = 2 },
			{ Type = "Wins", DurationMinutes = 15, Multiplier = 2 },
		},
		ProportionalRewards = true,
	},
	thankyousomuchfor20kvisits = {
		Marker = "Code_ThankYouSoMuchFor20kVisits_v1",
		Speed = 100000,
		Wins = 1000,
	},
	thankyousomuchfor777groupmembers = {
		Marker = "Code_ThankYouSoMuchFor777GroupMembers_v1",
		Speed = 100000,
		Wins = 1000,
	},
	reach87percentlike = {
		Marker = "Code_Reach87PercentLike_v1",
		Speed = 137000,
		Wins = 1770,
	},
	update2 = {
		Marker = "Code_Update2_v1",
		Potion = {
			Type = "Speed",
			DurationMinutes = 10,
		},
	},
	["7kccu"] = {
		Marker = "Code_7KCCU_v2",
		Speed = 250000,
		Wins = 7000,
		Potion = {
			Type = "Wins",
			DurationMinutes = 10,
			Multiplier = 2,
		},
	},
	["5mvisits"] = {
		Marker = "Code_5MVISITS_v1",
		Speed = 500000,
		Wins = 15000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 10,
			Multiplier = 2,
		},
	},
	["250kgroupmembers"] = {
		Marker = "Code_250KGROUPMEMBERS_v1",
		Speed = 350000,
		Wins = 10000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 10,
			Multiplier = 2,
		},
	},
	sorry4delayedupdate = {
		Marker = "Code_Sorry4DelayedUpdate_v1",
		Speed = 250000,
		Wins = 2500,
	},
	sorryfordelayedupdate = {
		Marker = "Code_Sorry4DelayedUpdate_v1",
		Speed = 250000,
		Wins = 2500,
	},
	sorry4delayedupdate2day = {
		Marker = "Code_Sorry4DelayedUpdate2day_v1",
		Speed = 500000,
		Wins = 10000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 15,
			Multiplier = 2,
		},
	},
	sorry4delayedupdate2 = {
		Marker = "Code_Sorry4DelayedUpdate2day_v1",
		Speed = 500000,
		Wins = 10000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 15,
			Multiplier = 2,
		},
	},
	sorryforthedelayedupdate2day = {
		Marker = "Code_Sorry4DelayedUpdate2day_v1",
		Speed = 500000,
		Wins = 10000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 15,
			Multiplier = 2,
		},
	},
	gifting = {
		Marker = "Code_Gifting_v1",
		Speed = 150000,
		Wins = 1500,
	},
	gift = {
		Marker = "Code_Gifting_v1",
		Speed = 150000,
		Wins = 1500,
	},
	gifts = {
		Marker = "Code_Gifting_v1",
		Speed = 150000,
		Wins = 1500,
	},
	admingiv3away = {
		Marker = "Code_AdminGiv3away_v1",
		Speed = 1000000,
		Wins = 25000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 15,
			Multiplier = 2,
		},
	},
	admingiveaway = {
		Marker = "Code_AdminGiv3away_v1",
		Speed = 1000000,
		Wins = 25000,
		Potion = {
			Type = "Speed",
			DurationMinutes = 15,
			Multiplier = 2,
		},
	},
}

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
