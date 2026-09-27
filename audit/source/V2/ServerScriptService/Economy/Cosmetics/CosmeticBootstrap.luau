local CosmeticService = require(script.Parent:WaitForChild("CosmeticService"))

local MAX_ATTEMPTS = 30
local RETRY_DELAY = 0.25

for attempt = 1, MAX_ATTEMPTS do
	local ok, initialized, message = pcall(function()
		local success, err = CosmeticService.Initialize()
		return success, err
	end)

	if ok and initialized == true then
		print("[CosmeticBootstrap] V306ED cosmetic service initialized on attempt " .. tostring(attempt) .. ".")
		return
	end

	local reason = ok and message or initialized
	warn(
		"[CosmeticBootstrap] Cosmetic init attempt "
			.. tostring(attempt)
			.. " failed: "
			.. tostring(reason)
	)
	task.wait(RETRY_DELAY)
end

error("[CosmeticBootstrap] Cosmetic service could not initialize after retries.")
