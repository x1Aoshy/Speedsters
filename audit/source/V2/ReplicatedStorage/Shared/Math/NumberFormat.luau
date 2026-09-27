--!strict
-- NumberFormat.luau
-- Utilidad pura para formatear números de velocidad, victorias y monedas.

local NumberFormat = {}

local SUFFIXES = {
	{ Threshold = 1e15, Symbol = "Q" },
	{ Threshold = 1e12, Symbol = "T" },
	{ Threshold = 1e9,  Symbol = "B" },
	{ Threshold = 1e6,  Symbol = "M" },
	{ Threshold = 1e3,  Symbol = "K" },
}

function NumberFormat.FormatCompact(value: number): string
	local num = tonumber(value) or 0
	if num < 0 then
		return "-" .. NumberFormat.FormatCompact(-num)
	end
	if num < 1000 then
		return string.format("%d", math.floor(num))
	end

	for _, entry in ipairs(SUFFIXES) do
		if num >= entry.Threshold then
			local formatted = num / entry.Threshold
			if formatted >= 100 then
				return string.format("%.0f%s", formatted, entry.Symbol)
			elseif formatted >= 10 then
				return string.format("%.1f%s", formatted, entry.Symbol)
			else
				return string.format("%.2f%s", formatted, entry.Symbol)
			end
		end
	end

	return tostring(math.floor(num))
end

function NumberFormat.FormatWithCommas(value: number): string
	local formatted = tostring(math.floor(tonumber(value) or 0))
	local k: number
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

return NumberFormat
