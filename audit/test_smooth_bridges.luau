-- test_smooth_bridges.luau
-- The plank bridges run smooth (2026-09-18, Sung's video: the wooden bridge jerked runners
-- at every plank). On World 2's Japanese Bridge and World 3's two Stage 5 bridges, planned
-- exactly as Gameplay/SmoothBridges plans them at server start:
--   * the deck's planks are found (and only planks: rails and posts stay solid);
--   * one ramp from the first plank's edge to the last's, its pieces meeting end to end;
--   * never under a plank's top (a hair over it), turning only a little from piece to piece;
--   * invisible and solid; the planks then only show.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local block = assert(string.match(configSource, "Config%.SmoothBridges = (%b{})"), "Config.SmoothBridges")
local settings = luau.load("return " .. block)()
local Plan = luau.load(fs.readFile("src/common/ServerScriptService/Gameplay/BridgeRampPlan.luau"), {
	environment = setmetatable({ Vector3 = rb.Vector3, CFrame = rb.CFrame }, { __index = _G }),
})()
assert(settings.Enabled and settings.World2[1] == "Japanese Bridge" and settings.World3[1] == "Bridge", "The Japanese Bridge and the Stage 5 bridges")

local bridges = 0
local currentPlaces = { World2 = "World2Update3new.rbxl", World3 = "World3Update3New.rbxl" }
for _, key in { "World2", "World3" } do
	local place = rb.deserializePlace(fs.readFile(currentPlaces[key]))
	for _, bridge in place.Workspace:GetDescendants() do
		if bridge:IsA("Model") and table.find(settings[key], bridge.Name) then
			bridges += 1
			local planks, rails = {}, 0
			for _, part in bridge:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					local plank = Plan.Plank(part.CFrame, part.Size)
					if plank then
						table.insert(planks, plank)
					else
						rails += 1
					end
				end
			end
			local where = key .. " " .. bridge:GetFullName()
			assert(#planks >= 8 and rails > 0, where .. ": planks found, rails and posts left solid (" .. #planks .. " / " .. rails .. ")")
			local pieces, deck = Plan.Ramp(planks)
			assert(pieces and deck, where .. ": a ramp")
			local deckPlanks = {}
			for index, plank in planks do
				if deck[index] then
					table.insert(deckPlanks, plank)
				end
			end
			assert(#deckPlanks >= 8, where .. ": the deck")
			-- The ramp's top line: each piece's top face, from end to end.
			local ends = {}
			for _, piece in pieces do
				local top = piece.CFrame * rb.CFrame.new(0, piece.Size.Y / 2, 0)
				local half = (piece.Size.Z - Plan.Overlap) / 2
				table.insert(ends, { A = top * rb.Vector3.new(0, 0, -half), B = top * rb.Vector3.new(0, 0, half), Look = piece.CFrame.LookVector, Up = piece.CFrame.UpVector })
				assert(piece.CFrame.UpVector.Y > 0.5, where .. ": each piece lies face up")
			end
			for index = 1, #ends - 1 do
				local a, b = ends[index], ends[index + 1]
				local joined = math.min((a.B - b.A).Magnitude, (a.A - b.B).Magnitude, (a.B - b.B).Magnitude, (a.A - b.A).Magnitude)
				assert(joined < 0.3, where .. ": the pieces meet end to end (" .. joined .. ")")
				local turn = math.deg(math.acos(math.clamp(a.Up:Dot(b.Up), -1, 1)))
				assert(turn < 15, where .. ": smooth from piece to piece (" .. turn .. " degrees)")
			end
			-- Never under a deck plank's top, and close over it.
			for _, plank in deckPlanks do
				local best = math.huge
				for _, piece in pieces do
					local localTop = piece.CFrame:PointToObjectSpace(plank.Top)
					if math.abs(localTop.Z) <= piece.Size.Z / 2 and math.abs(localTop.X) <= piece.Size.X / 2 + 1 then
						-- Height of the plank's top under the piece's top face.
						best = math.min(best, piece.Size.Y / 2 - localTop.Y)
					end
				end
				assert(best < math.huge, where .. ": every plank is under the ramp")
				assert(best >= -0.01 and best <= 1.2, where .. (": the ramp runs a hair over the planks (%.2f)"):format(best))
			end
			print(("PASS %s: %d deck planks under a smooth ramp of %d pieces; %d rails, posts and trims stay solid"):format(where, #deckPlanks, #pieces, rails + #planks - #deckPlanks))
		end
	end
end
assert(bridges == 3, "The Japanese Bridge and both Stage 5 bridges (" .. bridges .. ")")

local server = fs.readFile("src/common/ServerScriptService/Gameplay/SmoothBridges.server.luau")
for _, needle in { "part.Transparency = 1", "part.CanCollide = true", "if deck[index] then\n\t\t\t\t\tpart.CanCollide = false" } do
	assert(string.find(server, needle, 1, true), "The ramp and planks: " .. needle)
end
print("ALL SMOOTH BRIDGE CHECKS PASSED")
