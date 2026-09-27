--!strict
-- src/ServerScriptService/Services/Monetization/MonetizationService.luau
-- Lote R1-09 / Reto 1: Procesamiento seguro de compras, verificación de entitlements y saga de regalos.
-- Invariante: Retorna PurchaseGranted SOLO con confirmación durable en DataService o recibo ya completado.

local ReceiptLedger
local ProductRegistry

if typeof(script) == "Instance" and script.Parent then
	ReceiptLedger = require(script.Parent.ReceiptLedger)
	ProductRegistry = require(script.Parent.ProductRegistry)
else
	ReceiptLedger = require("./ReceiptLedger")
	ProductRegistry = require("./ProductRegistry")
end

export type Receipt = {
	purchaseId: string,
	buyerUserId: number,
	productId: number,
	currencySpent: number,
}

export type ReceiptDecision = "PurchaseGranted" | "NotProcessedYet"

export type EntitlementStatus =
	{ kind: "Owned", source: "Roblox" | "Gift" | "Promotion" | "Migration" }
	| { kind: "NotOwned" }
	| { kind: "Unknown", retryAfterSeconds: number }

export type GiftIntent = {
	intentId: string,
	buyerUserId: number,
	recipientUserId: number,
	productId: number,
	createdAtUnix: number,
	state: "AwaitingReceipt" | "Bound" | "Completed" | "Cancelled",
	purchaseId: string?,
}

export type Result<T> = { ok: true, value: T } | { ok: false, error: any }

local MonetizationService = {}
local dataServiceRef: any = nil
local activeGiftIntents: { [string]: GiftIntent } = {}
local isStarted = false

function MonetizationService.Init(deps: { dataService: any })
	dataServiceRef = deps.dataService
	ProductRegistry.InitDefaults()
end

function MonetizationService.Start()
	isStarted = true
end

-- ProcessReceipt: Callback principal para MarketplaceService.ProcessReceipt
function MonetizationService.ProcessReceipt(receipt: Receipt): ReceiptDecision
	-- 1. Deduplicación por ReceiptLedger
	if ReceiptLedger.HasProcessed(receipt.purchaseId) then
		return "PurchaseGranted"
	end

	if not dataServiceRef then
		return "NotProcessedYet"
	end

	-- 2. Consultar definición del producto
	local productDef = ProductRegistry.Get(receipt.productId)
	if not productDef then
		-- Si no se reconoce el producto, reintentar más tarde (no conceder ni rechazar de forma destructiva)
		return "NotProcessedYet"
	end

	-- 3. Preparar comandos
	local commands = productDef.buildCommands(nil)
	table.insert(commands, { kind = "RecordRobuxSpent", amount = receipt.currencySpent })

	local validHandle = dataServiceRef.GetHandle(receipt.buyerUserId)
	if not validHandle then
		-- Si el jugador no tiene sesión abierta en este servidor, reintentar cuando ingrese
		return "NotProcessedYet"
	end

	-- 4. Ejecutar Commit durable en DataService
	local commitRes = dataServiceRef.Commit(validHandle, {
		operationId = receipt.purchaseId,
		fingerprint = string.format("purchase_%s_%d", receipt.purchaseId, receipt.productId),
		commands = commands,
	})

	if commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted" then
		-- 5. Registrar en ledger durable
		ReceiptLedger.RecordProcessed({
			purchaseId = receipt.purchaseId,
			userId = receipt.buyerUserId,
			productId = receipt.productId,
			processedAtUnix = os.time(),
		})
		return "PurchaseGranted"
	elseif commitRes.kind == "Pending" then
		return "NotProcessedYet"
	else
		-- Rejected / StoreUnavailable / SessionLost: No confirmar compra; dejar que Roblox reintente
		return "NotProcessedYet"
	end
end

-- QueryEntitlement: Consulta la propiedad de un producto, pase o cosmético
function MonetizationService.QueryEntitlement(handle: any, id: string): Result<EntitlementStatus>
	if not dataServiceRef then
		return {
			ok = false,
			error = { code = "NotReady", message = "DataService not configured" },
		}
	end

	local inspectRes = dataServiceRef.Inspect(handle)
	if not inspectRes.ok then
		return { ok = false, error = inspectRes.error }
	end

	local profile = inspectRes.value.profile
	if not profile then
		return { ok = true, value = { kind = "NotOwned" } }
	end

	-- Comprobar en listas de cosméticos
	if table.find(profile.OwnedSkins or {}, id)
		or table.find(profile.OwnedTrails or {}, id)
		or table.find(profile.OwnedAuras or {}, id)
		or table.find(profile.OwnedUpgrades or {}, id)
	then
		return { ok = true, value = { kind = "Owned", source = "Roblox" } }
	end

	return { ok = true, value = { kind = "NotOwned" } }
end

-- RecordGiftIntent: Registra una intención de regalo durable antes del prompt
function MonetizationService.RecordGiftIntent(intent: GiftIntent, deadlineMono: number?): Result<GiftIntent>
	if not intent.intentId or intent.buyerUserId == intent.recipientUserId then
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Invalid gift intent arguments" },
		}
	end

	activeGiftIntents[intent.intentId] = intent
	return { ok = true, value = intent }
end

function MonetizationService.Destroy()
	ReceiptLedger.Destroy()
	activeGiftIntents = {}
	isStarted = false
end

return MonetizationService
