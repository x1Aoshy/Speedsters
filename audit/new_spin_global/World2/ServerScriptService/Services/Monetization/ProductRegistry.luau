--!strict
-- src/ServerScriptService/Services/Monetization/ProductRegistry.luau
-- Lote R1-09 / Reto 1: Catálogo de Developer Products y traducción a EconomyCommands.

export type ProductDefinition = {
	id: number,
	name: string,
	category: "Speed" | "Wins" | "Potion" | "Cosmetic",
	buildCommands: (player: any) -> { any },
}

local ProductRegistry = {}
local products: { [number]: ProductDefinition } = {}

-- Registro de productos estándar del juego
function ProductRegistry.Register(def: ProductDefinition)
	products[def.id] = def
end

function ProductRegistry.Get(productId: number): ProductDefinition?
	return products[productId]
end

-- Inicialización de catálogo por defecto
function ProductRegistry.InitDefaults()
	-- Developer Products de Speed
	ProductRegistry.Register({
		id = 1001,
		name = "+500 Speed",
		category = "Speed",
		buildCommands = function(_)
			return {
				{ kind = "GrantExact", stat = "Speed", amount = 500 },
			}
		end,
	})

	ProductRegistry.Register({
		id = 1002,
		name = "+5000 Speed",
		category = "Speed",
		buildCommands = function(_)
			return {
				{ kind = "GrantExact", stat = "Speed", amount = 5000 },
			}
		end,
	})

	-- Developer Products de Wins
	ProductRegistry.Register({
		id = 2001,
		name = "+10 Wins",
		category = "Wins",
		buildCommands = function(_)
			return {
				{ kind = "GrantExact", stat = "Wins", amount = 10 },
			}
		end,
	})

	-- Pociones
	ProductRegistry.Register({
		id = 3001,
		name = "Speed Potion 15m",
		category = "Potion",
		buildCommands = function(_)
			return {
				{ kind = "GrantBuff", grant = { kind = "SpeedPotion", addedSeconds = 900, multiplier = 2.0 } },
			}
		end,
	})
end

return ProductRegistry
