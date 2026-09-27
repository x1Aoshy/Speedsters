-- Finish the interrupted treadmill, Stage 9 trampoline and Stage TP changes together.
local Lib = require("./fable_build_lib")
local rb = require("@lune/roblox")
local fs = require("@lune/fs")
local Trampoline = require("../src/worlds/World1/ReplicatedStorage/Shared/World1Trampoline")
local C = "src/common/"
local W = "src/worlds/World1/"
local G = "output/FableTrampolineTeleportGui/backup_src/"
local T = "output/FableTacoMeteor/backup_src_v4/"
local sources = {
	{ source = C .. "ReplicatedStorage/Shared/TacoMeteor.luau", guard = T .. "TacoMeteor.luau" },
	{ source = C .. "StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau", guard = T .. "AdminTreadmillReveal.client.luau" },
	{ source = C .. "ServerScriptService/Admin/AdminAbusePanelService.server.luau", guard = T .. "AdminAbusePanelService.server.luau" },
	{ source = C .. "StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau", guard = G .. "InstantMovementController.client.luau" },
	{ source = C .. "StarterPlayer/StarterPlayerScripts/Movement/WallImpactAntiFling.client.luau", guard = G .. "WallImpactAntiFling.client.luau" },
	{ source = W .. "ReplicatedStorage/Shared/World1Trampoline.luau", worlds = { "World1" } },
	{ source = W .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1Trampoline.client.luau", worlds = { "World1" } },
	{ source = W .. "Workspace/Trampoline/Trampoline_Hitbox/Trampoline hitbox/Script.server.luau", worlds = { "World1" }, guard = G .. "TrampolineScript.server.luau" },
}

Lib.run({
	output = "output/FableTrampolineTeleportGui",
	sources = sources,
	edit = function(key, dm, notes)
		local scroll = dm:GetService("StarterGui").StageTeleport.StageTeleport.ScrollingFrame
		-- Restore the authored canvas: row heights are fractions of this canvas.
		-- Automatic sizing with a zero canvas halved the rows after Stage 11 was removed.
		scroll.AutomaticCanvasSize = rb.Enum.AutomaticSize.None
		scroll.CanvasSize = rb.UDim2.new(0, 0, 2, 0)
		table.insert(notes, "Stage TP authored row size restored (canvas Y=2)")
		if key == "World1" then
			local ws = dm:GetService("Workspace")
			local model = assert(ws:FindFirstChild("Trampoline"))
			local pad = assert(model:FindFirstChild("Trampoline hitbox", true))
			local ledge = assert(ws.neworld1:FindFirstChild("stage10", true))
			-- Clear the serialized conveyor as well as its runtime setter.
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.AssemblyLinearVelocity = rb.Vector3.zero
					part.Velocity = rb.Vector3.zero
				end
			end
			local rise = Trampoline.Rise(Trampoline.TopOf(pad.CFrame, pad.Size), Trampoline.TopOf(ledge.CFrame, ledge.Size))
			model:SetAttribute(Trampoline.RiseAttribute, rise)
			model:AddTag(Trampoline.Tag)
			table.insert(notes, ("trampoline rise %.2f, launch %.2f studs/s"):format(rise, Trampoline.LaunchSpeed(ws.Gravity, rise)))
		end
		return true
	end,
	verify = function(key, dm)
		local scroll = dm:GetService("StarterGui").StageTeleport.StageTeleport.ScrollingFrame
		assert(scroll.AutomaticCanvasSize == rb.Enum.AutomaticSize.None)
		assert(scroll.CanvasSize == rb.UDim2.new(0, 0, 2, 0))
		assert(not scroll:FindFirstChild("Stage11"), key .. ": Stage 11 must stay out of the paid menu")
		if key == "World1" then
			local model = dm:GetService("Workspace").Trampoline
			assert(model:HasTag(Trampoline.Tag))
			assert(model:GetAttribute(Trampoline.RiseAttribute) > 400)
			assert(model:FindFirstChild("Trampoline hitbox", true).Velocity == rb.Vector3.zero)
		end
	end,
})
