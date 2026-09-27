-- audit/u4_npc_r6.luau  (Update 4, 2026-09-25)
-- The owner's lobby NPC models (Eggmanr6andflashr15.rbxm: "eggman r6" and "Flash r15", both R15
-- rigs in fact) as standard R6 rigs, so the procedural R6 idles of Gameplay/LobbyNpcsClient
-- (Shared/LobbyNpcPose) drive them. Written to design/npc/LobbyCharacters.rbxm: a Folder
-- "LobbyCharacters" holding the models "Eggman" and "Flash" (names the NPC server adopts), each
-- standing on y = 0 at the origin, facing -Z. audit/build_update4.luau puts them in every lobby.
--
-- What is kept: the head (with its mesh, face and attachments), Shirt, Pants, BodyColors and every
-- rigid accessory, welded again to the same-named R6 attachment. The R15 body is replaced by the
-- R6 blocks (Torso 2x2x1, limbs 1x2x1) coloured from BodyColors or the R15 parts; the joints are
-- Roblox's standard R6 Motor6Ds (RootJoint, Neck, Left/Right Shoulder, Left/Right Hip).
-- A library: audit/build_npc_r6.luau writes the file; audit/build_update4.luau places the models.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3

local SOURCE = "Eggmanr6andflashr15.rbxm"
local OUTPUT = "design/npc/LobbyCharacters.rbxm"
local PI = math.pi

local R6 = {}

-- Roblox's standard R6 joints: name, parent part, Part0, Part1, C0, C1.
R6.Joints = {
	{ "RootJoint", "HumanoidRootPart", "HumanoidRootPart", "Torso",
		CFrame.new(0, 0, 0) * CFrame.Angles(-PI / 2, 0, PI), CFrame.new(0, 0, 0) * CFrame.Angles(-PI / 2, 0, PI) },
	{ "Right Shoulder", "Torso", "Torso", "Right Arm",
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, PI / 2, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, PI / 2, 0) },
	{ "Left Shoulder", "Torso", "Torso", "Left Arm",
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -PI / 2, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -PI / 2, 0) },
	{ "Right Hip", "Torso", "Torso", "Right Leg",
		CFrame.new(1, -1, 0) * CFrame.Angles(0, PI / 2, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, PI / 2, 0) },
	{ "Left Hip", "Torso", "Torso", "Left Leg",
		CFrame.new(-1, -1, 0) * CFrame.Angles(0, -PI / 2, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -PI / 2, 0) },
}

-- Roblox's standard R6 body attachments (the ones accessories and clothing use).
R6.Attachments = {
	Torso = {
		NeckAttachment = Vector3.new(0, 1, 0),
		BodyFrontAttachment = Vector3.new(0, 0, -0.5),
		BodyBackAttachment = Vector3.new(0, 0, 0.5),
		LeftCollarAttachment = Vector3.new(-1, 1, 0),
		RightCollarAttachment = Vector3.new(1, 1, 0),
		WaistFrontAttachment = Vector3.new(0, -1, -0.5),
		WaistCenterAttachment = Vector3.new(0, -1, 0),
		WaistBackAttachment = Vector3.new(0, -1, 0.5),
	},
	["Left Arm"] = { LeftShoulderAttachment = Vector3.new(0, 1, 0), LeftGripAttachment = Vector3.new(0, -1, 0) },
	["Right Arm"] = { RightShoulderAttachment = Vector3.new(0, 1, 0), RightGripAttachment = Vector3.new(0, -1, 0) },
	["Left Leg"] = { LeftFootAttachment = Vector3.new(0, -1, 0) },
	["Right Leg"] = { RightFootAttachment = Vector3.new(0, -1, 0) },
	Head = {
		FaceCenterAttachment = Vector3.new(0, 0, 0),
		FaceFrontAttachment = Vector3.new(0, 0, -0.6),
		HairAttachment = Vector3.new(0, 0.6, 0),
		HatAttachment = Vector3.new(0, 0.6, 0),
	},
}

-- Where each R6 block stands relative to the root (the R6 root centre is 3 studs over the floor).
local BLOCKS = {
	{ "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), { "UpperTorso" }, "TorsoColor3" },
	{ "Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), { "LeftUpperArm" }, "LeftArmColor3" },
	{ "Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0), { "RightUpperArm" }, "RightArmColor3" },
	{ "Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0), { "LeftUpperLeg" }, "LeftLegColor3" },
	{ "Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0), { "RightUpperLeg" }, "RightLegColor3" },
}
R6.RootHeight = 3

local function rigOf(model)
	-- A wrapper (Steal a Hero style: an outer model with a loose root) holds the rig in a child.
	if model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			return child
		end
	end
	return nil
end

local function colourOf(rig, bodyColors, key, r15Names)
	if bodyColors then
		local ok, value = pcall(function()
			return bodyColors[key]
		end)
		if ok and value then
			return value
		end
	end
	for _, name in r15Names do
		local part = rig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part.Color
		end
	end
	return roblox.Color3.fromRGB(245, 205, 150)
end

local function attachment(parent, name, position)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = CFrame.new(position)
	a.Parent = parent
	return a
end

-- Converts one R15 rig to an R6 model named `name`, root at (0, 3, 0) facing -Z. Returns the model
-- and notes.
function R6.Convert(source, name)
	local rig = assert(rigOf(source), name .. ": no Humanoid rig in " .. source.Name)
	local notes = {}
	local bodyColors = rig:FindFirstChildOfClass("BodyColors")
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, R6.RootHeight, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root

	local parts = { HumanoidRootPart = root }
	for _, block in BLOCKS do
		local part = Instance.new("Part")
		part.Name = block[1]
		part.Size = block[2]
		part.CFrame = root.CFrame * block[3]
		part.Color = colourOf(rig, bodyColors, block[5], block[4])
		part.Material = roblox.Enum.Material.SmoothPlastic
		part.TopSurface = roblox.Enum.SurfaceType.Smooth
		part.BottomSurface = roblox.Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Parent = model
		parts[block[1]] = part
	end

	-- The head: the owner's own (mesh, face, attachments), standing on the R6 neck.
	local oldHead = assert(rig:FindFirstChild("Head"), name .. ": no Head")
	local head = oldHead:Clone()
	for _, child in head:GetChildren() do
		if child:IsA("JointInstance") or child:IsA("Vector3Value") or child.Name == "NeckRigAttachment" then
			child.Parent = nil
		end
	end
	local neckRig = oldHead:FindFirstChild("NeckRigAttachment")
	local neckDrop = if neckRig then -neckRig.CFrame.Position.Y else head.Size.Y / 2
	head.CFrame = parts.Torso.CFrame * CFrame.new(0, 1 + neckDrop, 0)
	head.CanCollide = false
	head.Anchored = false
	head.Parent = model
	parts.Head = head
	table.insert(notes, ("head %s %s kept (neck %.3f)"):format(head.ClassName, tostring(head.Size), neckDrop))

	for _, joint in R6.Joints do
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = parts[joint[3]]
		motor.Part1 = parts[joint[4]]
		motor.C0 = joint[5]
		motor.C1 = joint[6]
		motor.Parent = parts[joint[2]]
	end
	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = parts.Torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-PI / 2, 0, PI)
	neck.C1 = CFrame.new(0, -neckDrop, 0) * CFrame.Angles(-PI / 2, 0, PI)
	neck.Parent = parts.Torso

	for partName, list in R6.Attachments do
		for attachmentName, position in list do
			attachment(parts[partName], attachmentName, position)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = roblox.Enum.HumanoidRigType.R6
	humanoid.HipHeight = 0
	humanoid.DisplayDistanceType = roblox.Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	for _, child in rig:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Clone().Parent = model
		end
	end

	-- Accessories: welded again to the same-named R6 attachment (their R15 welds point at parts
	-- that are gone).
	local byName = {}
	for _, part in parts do
		for _, a in part:GetChildren() do
			if a:IsA("Attachment") and byName[a.Name] == nil then
				byName[a.Name] = a
			end
		end
	end
	for _, accessory in rig:GetChildren() do
		if accessory:IsA("Accessory") then
			local copy = accessory:Clone()
			local handle = copy:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local handleAttachment = nil
				for _, child in handle:GetChildren() do
					if child:IsA("JointInstance") or child:IsA("RigidConstraint") or child:IsA("Vector3Value") then
						child.Parent = nil
					elseif child:IsA("Attachment") and byName[child.Name] and not handleAttachment then
						handleAttachment = child
					end
				end
				if handleAttachment then
					local bodyAttachment = byName[handleAttachment.Name]
					local body = bodyAttachment.Parent
					handle.CFrame = body.CFrame * bodyAttachment.CFrame * handleAttachment.CFrame:Inverse()
					local weld = Instance.new("Weld")
					weld.Name = "AccessoryWeld"
					weld.Part0 = handle
					weld.Part1 = body
					weld.C0 = handleAttachment.CFrame
					weld.C1 = bodyAttachment.CFrame
					weld.Parent = handle
					handle.Anchored = false
					handle.CanCollide = false
					handle.Massless = true
					copy.Parent = model
					table.insert(notes, ("%s -> %s.%s"):format(accessory.Name, body.Name, bodyAttachment.Name))
				else
					table.insert(notes, accessory.Name .. " SKIPPED (no attachment the R6 body has)")
				end
			end
		end
	end
	return model, notes
end

-- Moves every part of `model` (built at the origin, floor y = 0) by `frame`.
function R6.Place(model, frame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = frame * d.CFrame
		end
	end
end

R6.Source = SOURCE
R6.Output = OUTPUT

-- Run as a script: convert the owner's file and write the R6 models.
function R6.Build()
	local roots = roblox.deserializeModel(fs.readFile(SOURCE))
	local folder = roots[1]
	local eggmanSource, flashSource
	for _, child in folder:GetChildren() do
		local key = string.lower(child.Name)
		if string.find(key, "eggman", 1, true) then
			eggmanSource = child
		elseif string.find(key, "flash", 1, true) then
			flashSource = child
		end
	end
	assert(eggmanSource and flashSource, SOURCE .. ": expected an Eggman and a Flash model")
	local out = Instance.new("Folder")
	out.Name = "LobbyCharacters"
	for _, pair in { { eggmanSource, "Eggman" }, { flashSource, "Flash" } } do
		local model, notes = R6.Convert(pair[1], pair[2])
		model.Parent = out
		print(pair[2] .. ": " .. table.concat(notes, "; "))
	end
	for _, d in out:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "a script inside the NPC models: " .. d:GetFullName())
	end
	return out
end

return R6
