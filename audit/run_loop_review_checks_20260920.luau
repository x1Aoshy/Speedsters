local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local function adapted(original, output, substitutions)
	local source = fs.readFile(original)
	for _, pair in substitutions do
		local from, to = pair[1], pair[2]
		local first, last = source:find(from, 1, true)
		assert(first, "adaptation not found " .. from)
		while first do
			source = source:sub(1, first-1) .. to .. source:sub(last+1)
			first, last = source:find(from, first+#to, true)
		end
	end
	fs.writeFile(output, source)
	return output
end
local tests = {
	adapted("audit/persistence/test_regression.luau", "audit/persistence/test_current_loop_review.luau", { { "'../merged/'..world..'/ServerScriptService/Services/Data/", "'../../src/common/ServerScriptService/Services/Data/" } }),
	adapted("audit/test_new_persistence.luau", "audit/test_current_persistence_loop_review.luau", {
		{ "'./merged/'..world..'/ServerScriptService/Services/", "'../src/common/ServerScriptService/Services/" },
		{ "'audit/merged/'..world..'/ServerScriptService/Services/", "'src/common/ServerScriptService/Services/" },
	}),
	adapted("audit/test_pad_claim_contract.luau", "audit/test_current_pad_loop_review.luau", { { "'audit/merged/'..world..'/ServerScriptService/Services/'", "'src/common/ServerScriptService/Services/'" } }),
	"audit/test_core_loop_update.luau",
	"audit/test_treadmill_loop_regression.luau",
	"audit/test_wins_economy.luau",
	"audit/test_fable_teleport_price.luau",
	"audit/test_fable_trampoline.luau",
}
local results = {}
for index, test in tests do
	local result = process.exec("C:/Users/Aoshy´/.rokit/tool-storage/lune-org/lune/0.10.5/lune.exe", { "run", test })
	table.insert(results, { test = test, ok = result.ok, exitCode = result.code })
	fs.writeFile("output/LoopReview_20260920/check_" .. index .. ".log", (result.stdout or "") .. (result.stderr or ""))
	print(if result.ok then "PASS" else "FAIL", test)
	if not result.ok then print((result.stdout or ""):sub(-500), (result.stderr or ""):sub(-1800)) end
end
fs.writeFile("output/LoopReview_20260920/checks.json", serde.encode("json", results, true))
