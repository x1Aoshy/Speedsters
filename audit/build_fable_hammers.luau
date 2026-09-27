-- audit/build_fable_hammers.luau  (2026-09-20)
-- World 1: hammers swing on the clients (Shared/World1HammerMotion + NewWorld1HammerMotion), the
-- server keeps a virtual pose and leaves every other obstacle alone while nobody is near, and
-- each hammer model streams in whole (Atomic) so a client never swings half a hammer.
local Lib = require("./fable_build_lib")
local rb = require("@lune/roblox")
local W1 = "src/worlds/World1/"
Lib.run({
	output = "output/FableHammersAndMotion",
	sources = {
		{ source = W1 .. "ReplicatedStorage/Shared/World1HammerMotion.luau", worlds = { "World1" } },
		{ source = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1HammerMotion.client.luau", worlds = { "World1" } },
		{ source = W1 .. "ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau", worlds = { "World1" },
			guard = "output/FableHammersAndMotion/backup_src/NewWorld1ServerMotion.server.luau" },
	},
	edit = function(key, dm, notes)
		if key ~= "World1" then
			return false
		end
		local root = assert(dm:GetService("Workspace"):FindFirstChild("neworld1"), "neworld1 missing")
		local count = 0
		for index = 1, 5 do
			local hammer = root:FindFirstChild("Hammer" .. index, true)
			if hammer and hammer:IsA("Model") then
				hammer.ModelStreamingMode = rb.Enum.ModelStreamingMode.Atomic
				count += 1
			end
		end
		assert(count >= 4, "expected the four authored hammers, found " .. count)
		table.insert(notes, count .. " hammers set to Atomic streaming")
		return true
	end,
	verify = function(key, dm)
		if key == "World1" then
			local hammer = dm:GetService("Workspace").neworld1:FindFirstChild("Hammer3", true)
			assert(tostring(hammer.ModelStreamingMode):find("Atomic"), "Hammer3 is not Atomic after the round trip")
		end
	end,
})
