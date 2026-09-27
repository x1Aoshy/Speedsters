-- capture_skin_rigs.luau
-- The Superman and A-Train skins are worn from the R6 models the team placed in World 1's
-- Workspace (Studio save of 2026-09-18 11:39, kept in audit/studio_saves): "Superman" and
-- "V0_7H" (A-Train). This copies them, untouched in look (clothes, accessories, face, head
-- mesh and Body Colors), into src/assets/SkinRigs.rbxm, a ReplicatedStorage.SkinRigs folder
-- that build_core's ASSETS puts in every place: SkinSystem dresses players from it and the
-- Index / Evolve panels draw it as the skin's picture.
--
-- Only what is not part of the look is dropped: the HumanoidDescription and Animator the
-- avatar loader left under A-Train's Humanoid, and the cape's catalog thumbnail camera.
-- Body parts are anchored (a picture, never simulated); accessory handles are not.
--
-- Usage: lune run audit/capture_skin_rigs.luau
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")

local SOURCE = "audit/studio_saves/World1_2026-09-18_1139.rbxl"
local SOURCE_SHA256 = "657552dd15cc85d78cf97e5d4101862d0bd47c364b1baacafc1cf6ba159fa784"
local RIGS = {
	{ From = "Superman", Name = "Superman" },
	{ From = "V0_7H", Name = "ATrain" },
}

local raw = fs.readFile(SOURCE)
assert(serde.hash("sha256", raw) == SOURCE_SHA256, "The Studio save changed: " .. SOURCE)
local place = rb.deserializePlace(raw)

local folder = rb.Instance.new("Folder")
folder.Name = "SkinRigs"
for _, rig in RIGS do
	local source = assert(place.Workspace:FindFirstChild(rig.From), "Workspace." .. rig.From)
	local model = source:Clone()
	model.Name = rig.Name
	for _, d in model:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), rig.Name .. " carries a script: " .. d:GetFullName())
	end
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), rig.Name .. " has a Humanoid")
	assert(humanoid.RigType == rb.Enum.HumanoidRigType.R6, rig.Name .. " is an R6 rig")
	for _, child in humanoid:GetChildren() do
		child.Parent = nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Configuration") and d.Name == "ThumbnailConfiguration" then
			d.Parent = nil
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local inAccessory = d.Parent and d.Parent:IsA("Accessory")
			d.Anchored = not inAccessory
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	assert(model:FindFirstChildOfClass("BodyColors"), rig.Name .. " keeps its Body Colors")
	assert(model:FindFirstChildOfClass("Shirt") and model:FindFirstChildOfClass("Pants"), rig.Name .. " keeps its shirt and pants")
	assert(model.Head:FindFirstChild("face"), rig.Name .. " keeps its face")
	model.Parent = folder
	local accessories = 0
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			accessories += 1
		end
	end
	print(("captured %s (from Workspace.%s): %d accessories"):format(rig.Name, rig.From, accessories))
end

fs.writeFile("src/assets/SkinRigs.rbxm", rb.serializeModel({ folder }))
print("wrote src/assets/SkinRigs.rbxm")
