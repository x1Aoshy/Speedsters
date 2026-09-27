-- audit/build_fable_completion.luau  (2026-09-20)
-- The QoL pass: AFK spot / "[AFK]" tag / offline earnings / x5 product, World 2 Stage 10 trip,
-- the GO card after the camera flight, the tutorial's shade without seams, the HUD away during
-- the world-portal flight (Shared/InterfaceHider, new), "Runs" -> "Claim N Win Pads", overhead
-- titles over the head.
-- The list is exactly what scratch/fbq_diff_places.luau found different between src and the three
-- places. No guards: the places were compared with src right before this build, and the only
-- other writer (the suite-repair session) had finished. Every replaced Source is saved under
-- output/FableCompletion_20260920/backup/<World>/, next to the places as they were.
local Lib = require("./fable_build_lib")
local C = "src/common/"
local sources = {}
for _, path in {
	"ReplicatedStorage/Shared/InterfaceHider.luau",
	"ReplicatedStorage/Shared/Config.luau",
	"ReplicatedStorage/Shared/QuestCatalog.luau",
	"ReplicatedStorage/Shared/TutorialGuide.luau",
	"ReplicatedStorage/Shared/TutorialGuideLayout.luau",
	"ServerScriptService/Admin/AdminAbusePanelService.server.luau",
	"ServerScriptService/Bootstrap.server.luau",
	"ServerScriptService/Economy/SpeedProductPurchases.server.luau",
	"ServerScriptService/Progression/PlayerStats.server.luau",
	"ServerScriptService/Services/RewardPadClaims.luau",
	"ServerScriptService/Social/AfkRewardsService.server.luau",
	"ServerScriptService/Social/AfkZoneService.server.luau",
	"ServerScriptService/Social/QuestService.server.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau",
} do
	table.insert(sources, { source = C .. path })
end
Lib.run({ output = "output/FableCompletion_20260920", sources = sources })
