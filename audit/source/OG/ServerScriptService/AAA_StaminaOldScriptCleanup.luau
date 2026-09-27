local BAD_NAMES = {
	FinalFlashStaminaFix = true,
	FlashStaminaAuthority = true,
}

local function clean(container)
	for _, inst in ipairs(container:GetDescendants()) do
		if inst:IsA("BaseScript") and BAD_NAMES[inst.Name] == true then
			warn("[AAA_StaminaOldScriptCleanup] Removing old stamina script: " .. inst:GetFullName())
			inst.Disabled = true
			inst:Destroy()
		end
	end
end

clean(game)
task.delay(1, function()
	clean(game)
end)

print("[AAA_StaminaOldScriptCleanup] V125 loaded.")
