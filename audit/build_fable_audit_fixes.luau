-- audit/build_fable_audit_fixes.luau  (2026-09-20)
-- The audit's approved fixes (output/Auditoria_Integral_20260920): speed hot path, owner-only
-- sprint bar, state-remote limiter, join-only animation republish, no panels for new players,
-- small rate limits, phones without global shadows, and old characters destroyed.
local Lib = require("./fable_build_lib")
local rb = require("@lune/roblox")
local C = "src/common/"
local G = "output/FableAuditFixes/backup_src/"
local function guarded(path)
	return { source = C .. path, guard = G .. path:match("[^/]+$") }
end
Lib.run({
	output = "output/FableAuditFixes",
	sources = {
		{ source = C .. "ServerScriptService/Services/LatestStateLimiter.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Movement/StaminaSyncClient.client.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Gameplay/LowPowerGraphics.client.luau" },
		guarded("ServerScriptService/Bootstrap.server.luau"),
		guarded("ServerScriptService/Services/Data/SessionActor.luau"),
		guarded("ServerScriptService/Services/Data/DataService.luau"),
		guarded("ServerScriptService/Progression/PlayerStatsBridge.luau"),
		guarded("ServerScriptService/Progression/LevelProgress.server.luau"),
		guarded("ServerScriptService/Progression/RebirthSystem.server.luau"),
		guarded("ServerScriptService/Social/DailyLoginSystem.server.luau"),
		guarded("ServerScriptService/Economy/SkinSystem.server.luau"),
		guarded("ServerScriptService/Economy/SpeedProductPurchases.server.luau"),
		guarded("ServerScriptService/Infrastructure/AnimationReplicationSync.server.luau"),
		guarded("StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau"),
		guarded("StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"),
		-- Pacing: World 1's free treadmills unlock one rebirth apart (Candy 2, Diamond 4).
		guarded("ReplicatedStorage/Shared/Config.luau"),
	},
	edit = function(_, dm, notes)
		-- Bootstrap connects to each character's DescendantAdded; a destroyed character lets go of it.
		dm:GetService("Workspace").PlayerCharacterDestroyBehavior = rb.Enum.PlayerCharacterDestroyBehavior.Enabled
		table.insert(notes, "PlayerCharacterDestroyBehavior = Enabled")
		return true
	end,
	verify = function(key, dm)
		assert(tostring(dm:GetService("Workspace").PlayerCharacterDestroyBehavior):find("Enabled"), key)
	end,
})
