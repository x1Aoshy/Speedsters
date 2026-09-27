-- audit/build_fable_teleport_price.luau  (2026-09-20)
-- The teleport -> Win pad loop: a stage trip was priced with the damped ladder formula while the
-- pad beside its arrival pays with every multiplier, so the trip cost less than the pad paid.
-- Trips are now priced by Shared.WinsMath.GetStageTripPrice (every Wins multiplier the pads pay
-- with, doubled for owners of the x2 pads), in the three worlds.
local Lib = require("./fable_build_lib")
local C = "src/common/"
local G = "output/FableTeleportPrice/backup_src/"
Lib.run({
	output = "output/FableTeleportPrice",
	sources = {
		{ source = C .. "ReplicatedStorage/Shared/WinsMath.luau", guard = G .. "WinsMath.luau" },
		{ source = C .. "ReplicatedStorage/Shared/Config.luau", guard = G .. "Config.luau" },
		{ source = C .. "ServerScriptService/Worlds/TeleportSystem.server.luau", guard = G .. "TeleportSystem.server.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/UI/TeleportController.client.luau", guard = G .. "TeleportController.client.luau" },
	},
})
