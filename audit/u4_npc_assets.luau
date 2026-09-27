-- audit/u4_npc_assets.luau (Update 4, lobby NPCs, 2026-09-25)
-- Captures Steal a Hero's Flash (ReplicatedStorage.Assets.Models.Heroes.Flash: the owner's
-- downloaded R15 Flash, "Downloaded_Heroes_R15 > Flash") into design/npc/Flash.rbxm, so the owner
-- can drop it into a lobby in Studio (Gameplay/LobbyNpcs adopts any Model named "Flash") and
-- audit/test_u4_npcs can prove the idle runs on a real R15 rig. Nothing needs it at runtime: the
-- spawned Flash is the R6 avatar in the game's FlashSuit.
-- What it is: a standard R15 body (Roblox's block body meshes 7430071xxx), a custom head mesh
-- (123480233606534, texture 111092388570647), a Hair accessory (mesh 124733376778602, texture
-- 104177662731626), Shirt 955766284 (the FlashSuit shirt's template), Pants 81241748055946, face
-- 144075659; no scripts. Steal a Hero's bookkeeping attributes are dropped; the HumanoidRootPart
-- stays at the origin with the feet on y = 0, looking -Z.
-- Reads StealaHero.rbxl, never writes it. Run from the project root:
--   lune run audit/u4_npc_assets.luau [path/to/StealaHero.rbxl]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local SOURCE = process.args[1] or "C:/Users/Aoshy´/Desktop/StealaHero/StealaHero.rbxl"
local OUT_DIR = "design/npc"
local OUT_FILE = OUT_DIR .. "/Flash.rbxm"

assert(fs.isFile(SOURCE), "no Steal a Hero place at " .. SOURCE)
local game = roblox.deserializePlace(fs.readFile(SOURCE))
local heroes = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
heroes = heroes and heroes:FindFirstChild("Models")
heroes = heroes and heroes:FindFirstChild("Heroes")
local source = assert(heroes and heroes:FindFirstChild("Flash"), "ReplicatedStorage.Assets.Models.Heroes.Flash is missing")
assert(source:IsA("Model"), "Heroes.Flash is not a Model")

local model = source:Clone()
model.Name = "Flash"
local scripts = 0
for _, item in model:GetDescendants() do
	if item:IsA("LuaSourceContainer") then
		scripts += 1
		item:Destroy()
	end
end
for key in model:GetAttributes() do
	model:SetAttribute(key, nil)
end
model:SetAttribute("CapturedFrom", "Steal a Hero: ReplicatedStorage.Assets.Models.Heroes.Flash")

local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "no Humanoid")
local root = assert(model:FindFirstChild("HumanoidRootPart"), "no HumanoidRootPart")
local motors, parts = 0, 0
for _, item in model:GetDescendants() do
	if item:IsA("Motor6D") then
		motors += 1
	elseif item:IsA("BasePart") then
		parts += 1
	end
end
assert(motors == 15 and humanoid.RigType == roblox.Enum.HumanoidRigType.R15, "not the 15-joint R15 rig")

if not fs.isDir(OUT_DIR) then
	fs.writeDir(OUT_DIR)
end
fs.writeFile(OUT_FILE, roblox.serializeModel({ model }))

-- The file reads back as the same rig.
local back = roblox.deserializeModel(fs.readFile(OUT_FILE))
assert(#back == 1 and back[1].Name == "Flash" and back[1]:FindFirstChild("HumanoidRootPart"), "the capture does not read back")
print(("captured %s -> %s: R15, %d parts, %d Motor6Ds, %d scripts removed, root at %s"):format(
	source:GetFullName(), OUT_FILE, parts, motors, scripts, tostring(root.CFrame.Position)))
