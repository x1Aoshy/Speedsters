--!strict
-- CodesCatalog.luau
-- Catálogo centralizado y autoritativo de códigos promocionales para Speedter Game.

export type CodeDefinition = {
	Marker: string,
	Speed: number?,
	Wins: number?,
	Potion: {
		Type: "Speed" | "Wins",
		DurationMinutes: number,
		Multiplier: number?,
	}?,
}

local CodesCatalog: { [string]: CodeDefinition } = {
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
