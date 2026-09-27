--!strict
-- src/ServerScriptService/Services/Monetization/ReceiptLedger.luau
-- Lote R1-09 / Reto 1: Ledger de recibos procesados para garantizar entrega exactamente una vez.

export type LedgerEntry = {
	purchaseId: string,
	userId: number,
	productId: number,
	processedAtUnix: number,
}

local ReceiptLedger = {}
local processedMap: { [string]: LedgerEntry } = {}

function ReceiptLedger.HasProcessed(purchaseId: string): boolean
	return processedMap[purchaseId] ~= nil
end

function ReceiptLedger.RecordProcessed(entry: LedgerEntry)
	processedMap[entry.purchaseId] = entry
end

function ReceiptLedger.Clear(purchaseId: string)
	processedMap[purchaseId] = nil
end

function ReceiptLedger.Destroy()
	processedMap = {}
end

function ReceiptLedger.GetCount(): number
	local count = 0
	for _ in pairs(processedMap) do
		count = count + 1
	end
	return count
end

return ReceiptLedger
