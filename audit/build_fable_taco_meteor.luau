-- audit/build_fable_taco_meteor.luau  (2026-09-20, v2)
-- The Taco Treadmill arrives as a meteor: Shared/TacoMeteor + the taco branch of the reveal,
-- the V40 fire assets (src/ui/TacoMeteorAssets.rbxm, made by audit/capture_taco_meteor_assets)
-- in ReplicatedStorage.Shared, the tacos hung on the treadmill (AdminAbusePanelService), and
-- the sprite-sheet fix for every code-built taco / firework emitter (Shared/ParticleFlipbooks).
local Lib = require("./fable_build_lib")
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local C = "src/common/"
local G = "output/FableTacoMeteor/backup_src/"
Lib.run({
	output = "output/FableTacoMeteor",
	sources = {
		{ source = C .. "ReplicatedStorage/Shared/TacoMeteor.luau", guard = "output/FableTacoMeteor/backup_src_v4/TacoMeteor.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau",
			guard = "output/FableTacoMeteor/backup_src_v3/AdminAbusePanelController.client.luau" },
		{ source = C .. "ReplicatedStorage/Shared/ParticleFlipbooks.luau" },
		{ source = C .. "ReplicatedStorage/Shared/TacoFire.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Admin/TacoTreadmillFloat.client.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
			guard = "output/FableTacoMeteor/backup_src_v4/AdminTreadmillReveal.client.luau" },
		{ source = C .. "StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
			guard = G .. "AdminAbuseEffects.client.luau" },
		{ source = C .. "ServerScriptService/Admin/AdminAbusePanelService.server.luau",
			guard = "output/FableTacoMeteor/backup_src_v4/AdminAbusePanelService.server.luau" },
	},
	edit = function(_, dm, notes)
		local shared = dm:GetService("ReplicatedStorage").Shared
		local old = shared:FindFirstChild("TacoMeteorAssets")
		if old then
			old:Destroy()
		end
		local assets = rb.deserializeModel(fs.readFile("src/ui/TacoMeteorAssets.rbxm"))[1]
		assert(assets.Name == "TacoMeteorAssets")
		assets.Parent = shared
		table.insert(notes, "Shared.TacoMeteorAssets (" .. #assets:GetDescendants() .. " instances)")
		return true
	end,
	verify = function(key, dm)
		local assets = assert(dm:GetService("ReplicatedStorage").Shared:FindFirstChild("TacoMeteorAssets"), key)
		local grids = 0
		for _, item in assets:GetDescendants() do
			assert(not item:IsA("LuaSourceContainer"), key .. ": a script came in with the fire assets")
			if item:IsA("ParticleEmitter") and tostring(item.FlipbookLayout):find("Grid") then
				grids += 1
			end
		end
		assert(grids > 20, key .. ": the fire lost its sprite grids on the way into the place")
	end,
})
