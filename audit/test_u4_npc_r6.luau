-- audit/test_u4_npc_r6.luau  (Update 4, 2026-09-25)
-- The owner's Eggman and Flash (two R15 rigs in Eggmanr6andflashr15.rbxm) as R6 rigs the lobby NPC
-- system animates: standard R6 parts and Motor6Ds, feet on the floor, clothing and accessories
-- kept and welded to R6 attachments, names the NPC server adopts, no scripts;
-- design/npc/LobbyCharacters.rbxm is what the converter makes today. With "places": each lobby
-- carries both at its Shared/LobbyNpcConfig spot.
--   lune run audit/test_u4_npc_r6.luau [places]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local R6 = require("./u4_npc_r6")
local Npc = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local EggMobile = require("../src/common/ReplicatedStorage/Shared/EggMobile")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end

local converted = R6.Build()
local PARTS = { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
for _, model in converted:GetChildren() do
	assert(Npc.KindForName(model.Name) == model.Name, model.Name .. " is a name the NPC server adopts")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid and humanoid.RigType == roblox.Enum.HumanoidRigType.R6, model.Name .. ": an R6 Humanoid")
	for _, name in PARTS do
		assert(model:FindFirstChild(name) and model[name]:IsA("BasePart"), model.Name .. ": " .. name)
	end
	assert(model.PrimaryPart == model.HumanoidRootPart and model.HumanoidRootPart.Anchored, model.Name .. ": the anchored root is the PrimaryPart")
	-- Every joint the NPC poses turn (Shared/LobbyNpcConfig.JointMap, R6 names), in its R6 parent.
	local joints = {
		RootJoint = { "HumanoidRootPart", "HumanoidRootPart", "Torso" },
		Neck = { "Torso", "Torso", "Head" },
		["Left Shoulder"] = { "Torso", "Torso", "Left Arm" },
		["Right Shoulder"] = { "Torso", "Torso", "Right Arm" },
		["Left Hip"] = { "Torso", "Torso", "Left Leg" },
		["Right Hip"] = { "Torso", "Torso", "Right Leg" },
	}
	for name, want in joints do
		local motor = model[want[1]]:FindFirstChild(name)
		assert(motor and motor:IsA("Motor6D") and motor.Part0 == model[want[2]] and motor.Part1 == model[want[3]],
			model.Name .. ": Motor6D " .. name)
		-- The joint holds the rest pose as built: Part0 * C0 == Part1 * C1.
		local a, b = motor.Part0.CFrame * motor.C0, motor.Part1.CFrame * motor.C1
		assert((a.Position - b.Position).Magnitude < 1e-3, model.Name .. ": " .. name .. " holds the rest pose")
	end
	for _, name in Npc.RequiredJoints do
		assert(model:FindFirstChild(name, true), model.Name .. ": required joint " .. name)
	end
	-- Feet on the floor (y = 0 at the origin), root 3 studs up.
	for _, leg in { "Left Leg", "Right Leg" } do
		local part = model[leg]
		assert(near(part.CFrame.Position.Y - part.Size.Y / 2, 0), model.Name .. ": " .. leg .. " stands on the floor")
	end
	assert(model:FindFirstChildOfClass("Shirt") and model:FindFirstChildOfClass("Pants"), model.Name .. ": Shirt and Pants kept")
	local accessories = 0
	for _, accessory in model:GetChildren() do
		if accessory:IsA("Accessory") then
			accessories += 1
			local handle = accessory.Handle
			local weld = handle:FindFirstChild("AccessoryWeld")
			assert(weld and weld.Part0 == handle and weld.Part1 and weld.Part1:IsDescendantOf(model), model.Name .. ": " .. accessory.Name .. " welded to the R6 body")
			local a, b = weld.Part0.CFrame * weld.C0, weld.Part1.CFrame * weld.C1
			assert((a.Position - b.Position).Magnitude < 1e-3, model.Name .. ": " .. accessory.Name .. " sits where its weld puts it")
		end
	end
	assert(accessories > 0, model.Name .. ": accessories kept")
	for _, d in model:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), model.Name .. ": no scripts")
		assert(not d:IsA("AnimationController"), model.Name .. ": no AnimationController")
	end
end
assert(converted:FindFirstChild("Eggman") and converted:FindFirstChild("Flash"), "both characters")
assert(#converted.Eggman:GetChildren() >= 15, "Eggman keeps his collar, mustache, mask, goggles and coat")
pass("Eggman and Flash are standard R6 rigs: joints at rest, feet on the floor, clothing and accessories kept, adoptable names, no scripts")

local written = roblox.deserializeModel(fs.readFile(R6.Output))[1]
for _, name in { "Eggman", "Flash" } do
	local a, b = written:FindFirstChild(name), converted:FindFirstChild(name)
	assert(a and #a:GetDescendants() == #b:GetDescendants(), R6.Output .. " is today's conversion (" .. name .. ")")
end
pass(R6.Output .. " matches a fresh conversion")

if process.args[1] == "places" then
	for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
		local dm = roblox.deserializePlace(fs.readFile(place[2]))
		local folder = dm:GetService("Workspace"):FindFirstChild("LobbyCharacters")
		assert(folder and folder:GetAttribute("U4Asset") == "LobbyCharacters", place[1] .. ": Workspace.LobbyCharacters")
		for _, name in { "Eggman", "Flash" } do
			local model = folder:FindFirstChild(name)
			local spot = Npc.Spot(place[1], name)
			assert(model and spot, place[1] .. ": " .. name)
			local root = model.HumanoidRootPart.CFrame.Position
			local want = spot.Position + roblox.Vector3.new(0, R6.RootHeight, 0)
			-- 2026-09-26 (owner): Eggman sits in his Egg Mobile on that spot (audit/test_u4_egg_mobile).
			if name == "Eggman" and model:FindFirstChild(EggMobile.ModelName) then
				want = EggMobile.SeatCFrame(Npc.SpotCFrame(spot, roblox.CFrame), roblox.CFrame).Position
			end
			assert((root - want).Magnitude < 0.05, place[1] .. ": " .. name .. " stands at its lobby spot")
		end
	end
	pass("every lobby carries Eggman and Flash at their LobbyNpcConfig spots")
end
print(("test_u4_npc_r6: %d checks passed"):format(passed))
