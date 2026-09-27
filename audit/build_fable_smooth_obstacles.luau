-- audit/build_fable_smooth_obstacles.luau  (2026-09-20)
-- World 1: presses, lasers, sliding floor, "fast" block and rising lava move on the clients
-- from tracks the server publishes once (Shared/World1ObstacleMotion + NewWorld1TrackMotion);
-- hammers keep their own mover with wider radii. v2: the rolling cylinder too (a "Roll" track),
-- so the server moves nothing, and no client moves an obstacle its runner has already passed.
local Lib = require("./fable_build_lib")
local W1 = "src/worlds/World1/"
Lib.run({
	output = "output/FableSmoothObstacles",
	sources = {
		{ source = W1 .. "ReplicatedStorage/Shared/World1ObstacleMotion.luau", worlds = { "World1" },
			guard = "output/FableSmoothObstacles/backup_src_v2/World1ObstacleMotion.luau" },
		{ source = W1 .. "ReplicatedStorage/Shared/World1HammerMotion.luau", worlds = { "World1" },
			guard = "output/FableSmoothObstacles/backup_src_v2/World1HammerMotion.luau" },
		{ source = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1TrackMotion.client.luau", worlds = { "World1" },
			guard = "output/FableSmoothObstacles/backup_src_v2/NewWorld1TrackMotion.client.luau" },
		{ source = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1HammerMotion.client.luau", worlds = { "World1" },
			guard = "output/FableSmoothObstacles/backup_src_v2/NewWorld1HammerMotion.client.luau" },
		{ source = W1 .. "ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau", worlds = { "World1" },
			guard = "output/FableSmoothObstacles/backup_src_v2/NewWorld1ServerMotion.server.luau" },
	},
})
